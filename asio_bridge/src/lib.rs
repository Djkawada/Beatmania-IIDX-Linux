use std::net::UdpSocket;
use windows::core::HRESULT;
use windows::Win32::Foundation::CLASS_E_CLASSNOTAVAILABLE;

static mut SOCKET: Option<UdpSocket> = None;

#[no_mangle]
pub extern "system" fn DirectSoundCreate8(
    _lp_guid: *const std::ffi::c_void,
    _pp_ds8: *mut *mut std::ffi::c_void,
    _p_unk_outer: *mut std::ffi::c_void,
) -> HRESULT {
    unsafe {
        if SOCKET.is_none() {
            if let Ok(sock) = UdpSocket::bind("127.0.0.1:0") {
                let _ = sock.connect("127.0.0.1:44100");
                SOCKET = Some(sock);
            }
        }
    }
    
    // We intentionally fail to force the game to see our presence
    // In a future version, we would implement the full capture here.
    CLASS_E_CLASSNOTAVAILABLE
}

#[no_mangle]
pub extern "C" fn spice_init(_params: *const std::ffi::c_void) -> i32 {
    0
}
