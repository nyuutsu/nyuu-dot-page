use std::ffi::CStr;
use std::os::raw::c_char;

/// Read image dimensions from a file path, writing width and height to out-pointers.
///
/// Returns 0 on success, -1 on failure.
///
/// # Safety
///
/// `path` must be a valid null-terminated C string.
/// `out_width` and `out_height` must be valid, aligned, writable pointers.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn image_dimensions(
    path: *const c_char,
    out_width: *mut u32,
    out_height: *mut u32,
) -> i32 {
    let path = unsafe { CStr::from_ptr(path) };
    let Ok(path) = path.to_str() else { return -1 };

    match imagesize::size(path) {
        Ok(dims) => {
            unsafe {
                *out_width = dims.width as u32;
                *out_height = dims.height as u32;
            }
            0
        }
        Err(_) => -1,
    }
}
