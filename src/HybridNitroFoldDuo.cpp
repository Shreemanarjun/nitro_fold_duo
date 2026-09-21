// HybridNitroFoldDuo — the desktop implementation.
//
// Windows and Linux have no folding display and no vertical control bar, so
// every query answers "no Duo" and every bar call is accepted and ignored.
// The point is that a cross-platform app can call this API unconditionally:
// `isSupported` is false, the region list is empty, and nothing throws.
#include "../lib/src/generated/cpp/nitro_fold_duo.native.g.h"

namespace {

DuoState unavailable() {
    DuoState state;
    state.isSupported = false;
    state.hingeStatus = DUOHINGESTATUS_UNKNOWN;
    state.verticalBarEdge = DUOVERTICALBAREDGE_UNSPECIFIED;
    state.hingeAngle = std::nullopt;
    state.regions = {};
    state.cornerInsets = DuoInsets{0.0, 0.0, 0.0, 0.0};
    return state;
}

}  // namespace

class HybridNitroFoldDuoImpl final : public HybridNitroFoldDuo {
public:
    NitroCppBuffer currentState() override {
        return unavailable().toNativeBuffer();
    }

    void updateGlassCapsule(int64_t, NitroCppBuffer, NitroCppBuffer, int64_t,
                            int64_t, double, bool) override {}

    void updateGlassSurface(int64_t, double, int64_t, bool) override {}

    void setGlassCapsuleMenu(int64_t, int64_t, NitroCppBuffer,
                             NitroCppBuffer) override {}
};

static HybridNitroFoldDuoImpl g_impl;

// Auto-register on shared library load — no manual init call needed.
#if defined(_WIN32) || (defined(__linux__) && !defined(__ANDROID__))
#if defined(_WIN32)
namespace {
  struct _AutoRegister {
    _AutoRegister() { nitro_fold_duo_register_impl(&g_impl); }
  };
  _AutoRegister _auto_register_instance;
}
#else
__attribute__((constructor))
static void nitro_fold_duo_auto_register() {
    nitro_fold_duo_register_impl(&g_impl);
}
#endif
#endif // auto-register on C++ platforms
