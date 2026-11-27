//! FidelityFX Super Resolution 2 integration for Victory.
//! Uses fsr_sys directly to avoid windows version mismatch.

#[cfg(windows)]
use std::ptr;

#[cfg(windows)]
use windows::Win32::Graphics::Direct3D12::*;
#[cfg(windows)]
use windows::Win32::Graphics::Dxgi::Common::DXGI_FORMAT;

#[cfg(windows)]
use fsr_sys::d3d12::{GetInterfaceDX12, GetDeviceDX12, GetScratchMemorySizeDX12, GetResourceDX12, GetCommandListDX12};
#[cfg(windows)]
use fsr_sys::{FFX_OK, Interface as FfiInterface, Resource as FfiResource, Context as FfiContext, DispatchDescription as FfiDispatchDescription, Device as FfiDevice, Dimensions2D, FloatCoords2D, ResourceStates};
#[cfg(windows)]
use widestring::U16String;

/// FSR 2 context - wraps the raw FFI context.
/// Requires FSR 2 DLL (ffx-fsr2.dll) to be available in PATH or local directory.
#[cfg(windows)]
pub struct FsrContext {
    pub context: Option<Box<FfiContext>>,
    pub interface: Option<FfiInterface>,
    pub scratch_buffer: Option<Vec<u8>>,
    pub device: Option<FfiDevice>,
    pub render_width: u32,
    pub render_height: u32,
    pub display_width: u32,
    pub display_height: u32,
    pub initialized: bool,
}

#[cfg(windows)]
impl FsrContext {
    /// Create new FSR 2 context.
    pub fn new(
        _device: &ID3D12Device,
        _command_queue: &ID3D12CommandQueue,
        render_width: u32,
        render_height: u32,
        display_width: u32,
        display_height: u32,
    ) -> Self {
        Self {
            context: None,
            interface: None,
            scratch_buffer: None,
            device: None,
            render_width,
            render_height,
            display_width,
            display_height,
            initialized: false,
        }
    }

    /// Initialize FSR 2 context.
    /// Returns true if FSR 2 DLL is available and context created.
    pub fn initialize(&mut self, device: &mut ID3D12Device) -> bool {
        // Get scratch memory size
        let scratch_size = unsafe { GetScratchMemorySizeDX12() };
        if scratch_size == 0 {
            tracing::warn!("FSR 2: GetScratchMemorySizeDX12 returned 0");
            self.initialized = false;
            return false;
        }

        // Allocate scratch buffer
        let mut scratch_buffer = vec![0u8; scratch_size];

        // Get the FSR interface - this loads the ffx-fsr2.dll
        let mut ffi_interface = FfiInterface::default();
        let result = unsafe {
            GetInterfaceDX12(
                &mut ffi_interface,
                device as *mut _ as _,
                scratch_buffer.as_mut_ptr().cast(),
                scratch_buffer.len(),
            )
        };

        if result != FFX_OK {
            tracing::warn!("FSR 2: GetInterfaceDX12 failed with error code: {} (ffx-fsr2.dll not found?)", result);
            self.initialized = false;
            return false;
        }

        // Get the FSR device
        let fsr_device = unsafe { GetDeviceDX12(device as *mut _ as _) };

        // Create the FSR context
        let mut context = Box::new(FfiContext::default());
        let ffi_desc = fsr_sys::ContextDescription {
            callbacks: ffi_interface,
            flags: fsr_sys::FFX_FSR2_ENABLE_HIGH_DYNAMIC_RANGE as u32,
            maxRenderSize: Dimensions2D {
                width: self.render_width,
                height: self.render_height,
            },
            displaySize: Dimensions2D {
                width: self.display_width,
                height: self.display_height,
            },
            device: fsr_device,
            fpMessage: None,
        };

        let result = unsafe { fsr_sys::ContextCreate(context.as_mut(), &ffi_desc) };
        if result != FFX_OK {
            tracing::warn!("Failed to create FSR 2 context: error code {}", result);
            self.initialized = false;
            return false;
        }

        tracing::info!(
            "FSR 2 context created: {}x{} -> {}x{}",
            self.render_width, self.render_height,
            self.display_width, self.display_height
        );

        self.context = Some(context);
        self.interface = Some(ffi_interface);
        self.scratch_buffer = Some(scratch_buffer);
        self.device = Some(fsr_device);
        self.initialized = true;
        true
    }

    /// Register a texture resource with the FSR context.
    fn register_resource(
        ctx: &FfiContext,
        resource: &mut ID3D12Resource,
        state: ResourceStates,
        name: &str,
        is_depth: bool,
    ) -> Option<FfiResource> {
        // Get resource description
        let desc = unsafe { resource.GetDesc() };
        
        // Convert name to wide string
        let wide_name = U16String::from_str(name);
        let mut name_arr = [0u16; 64];
        let name_slice = wide_name.as_slice();
        let copy_len = name_slice.len().min(63);
        name_arr[..copy_len].copy_from_slice(&name_slice[..copy_len]);
        
        // Determine surface format from DXGI format
        let format: i32 = match desc.Format.0 {
            27..=32 => 8,   // R8G8B8A8_UNORM
            87 | 90 | 91 => 8, // B8G8R8A8_UNORM
            23..=25 => 7,   // R10G10B10A2_UNORM
            9..=14 => 3,    // R16G16B16A16_FLOAT
            2..=6 => 2,     // R32G32B32A32_FLOAT
            _ => 0,         // UNKNOWN
        };
        
        // Determine resource type
        let resource_type: i32 = if desc.Dimension.0 == 3 { // D3D12_RESOURCE_DIMENSION_TEXTURE2D
            1 // TEXTURE_2D
        } else if desc.Dimension.0 == 2 { // D3D12_RESOURCE_DIMENSION_TEXTURE1D
            0 // TEXTURE_1D
        } else {
            1 // default to 2D
        };
        
        let ffi_resource = unsafe {
            GetResourceDX12(
                ctx as *const _ as *mut _,
                resource as *mut _ as _,
                name_arr.as_ptr(),
                state,
                0, // shader_component_mapping
            )
        };
        
        Some(ffi_resource)
    }

    /// Dispatch FSR 2 upscale for a frame.
    /// Returns true if FSR dispatch succeeded.
    pub fn upscale(
        &mut self,
        command_list: &mut ID3D12GraphicsCommandList,
        color: &mut ID3D12Resource,
        depth: Option<&mut ID3D12Resource>,
        motion_vectors: Option<&mut ID3D12Resource>,
        output: &mut ID3D12Resource,
        reset: bool,
        _frame_index: u32,
        frame_time_delta: f32,
    ) -> bool {
        if !self.initialized {
            return false;
        }

        let ctx = match &mut self.context {
            Some(ctx) => ctx.as_mut(),
            None => return false,
        };

        // Register resources with FSR context and get resource handles
        // ResourceStates: COMPUTE_READ = 2, UNORDERED_ACCESS = 1
        let color_resource = match Self::register_resource(ctx, color, ResourceStates::COMPUTE_READ, "fsr_color", false) {
            Some(r) => r,
            None => {
                tracing::warn!("FSR 2: Failed to register color resource");
                return false;
            }
        };
        
        let depth_resource = match depth {
            Some(d) => match Self::register_resource(ctx, d, ResourceStates::COMPUTE_READ, "fsr_depth", true) {
                Some(r) => r,
                None => {
                    tracing::warn!("FSR 2: Failed to register depth resource");
                    return false;
                }
            },
            None => {
                tracing::warn!("FSR 2 requires depth buffer");
                return false;
            }
        };
        
        let motion_resource = match motion_vectors {
            Some(m) => match Self::register_resource(ctx, m, ResourceStates::COMPUTE_READ, "fsr_motion_vectors", false) {
                Some(r) => r,
                None => {
                    tracing::warn!("FSR 2: Failed to register motion vectors resource");
                    return false;
                }
            },
            None => {
                tracing::warn!("FSR 2 requires motion vectors");
                return false;
            }
        };
        
        let output_resource = match Self::register_resource(ctx, output, ResourceStates::UNORDERED_ACCESS, "fsr_output", false) {
            Some(r) => r,
            None => {
                tracing::warn!("FSR 2: Failed to register output resource");
                return false;
            }
        };

        // Create FFI command list from D3D12 command list
        let ffi_cmd_list = unsafe { GetCommandListDX12(command_list as *mut _ as _) };

        // Create dispatch description
        let ffi_dispatch = FfiDispatchDescription {
            commandList: ffi_cmd_list,
            output: output_resource,
            color: color_resource,
            depth: depth_resource,
            motionVectors: motion_resource,
            colorOpaqueOnly: FfiResource::default(),
            exposure: FfiResource::default(),
            reactive: FfiResource::default(),
            transparencyAndComposition: FfiResource::default(),
            enableAutoReactive: false,
            enableSharpening: false,
            autoReactiveMax: 0.0,
            autoTcScale: 1.0,
            autoReactiveScale: 1.0,
            autoTcThreshold: 0.0,
            motionVectorScale: FloatCoords2D { x: 1.0, y: 1.0 },
            preExposure: 1.0,
            frameTimeDelta: frame_time_delta,
            jitterOffset: FloatCoords2D { x: 0.0, y: 0.0 },
            renderSize: Dimensions2D {
                width: self.render_width,
                height: self.render_height,
            },
            cameraNear: 0.01,
            cameraFar: 1000.0,
            cameraFovAngleVertical: 1.0,
            sharpness: 0.0,
            viewSpaceToMetersFactor: 1.0,
            reset,
        };

        // Dispatch FSR
        let result = unsafe { fsr_sys::ContextDispatch(ctx, &ffi_dispatch) };
        if result != FFX_OK {
            tracing::warn!("FSR 2 dispatch failed: error code {}", result);
            return false;
        }

        true
    }

    /// Clean up FSR 2 context.
    pub fn destroy(&mut self) {
        if self.initialized {
            if let Some(ctx) = &mut self.context {
                let _ = unsafe { fsr_sys::ContextDestroy(ctx.as_mut()) };
            }
            self.context = None;
            self.interface = None;
            self.scratch_buffer = None;
            self.device = None;
            self.initialized = false;
        }
    }
}

#[cfg(windows)]
impl Drop for FsrContext {
    fn drop(&mut self) {
        self.destroy();
    }
}

/// Stub for non-Windows platforms
#[cfg(not(windows))]
pub struct FsrContext;

#[cfg(not(windows))]
impl FsrContext {
    pub fn new(
        _device: &mut (),
        _command_queue: &mut (),
        _render_width: u32,
        _render_height: u32,
        _display_width: u32,
        _display_height: u32,
    ) -> Self {
        Self
    }

    pub fn initialize(&mut self, _device: &mut ()) -> bool { false }

    pub fn upscale(
        &mut self,
        _command_list: &mut (),
        _color: &mut (),
        _depth: Option<&mut ()>,
        _motion_vectors: Option<&mut ()>,
        _output: &mut (),
        _reset: bool,
        _frame_index: u32,
        _frame_time_delta: f32,
    ) -> bool { false }

    pub fn destroy(&mut self) {}
}