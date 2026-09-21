package dev.shreeman.nitro_fold_duo

import android.app.Activity
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.RoundedCorner
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.launch
import nitro.nitro_fold_duo_module.DuoBarPress
import nitro.nitro_fold_duo_module.DuoHingeStatus
import nitro.nitro_fold_duo_module.DuoInsets
import nitro.nitro_fold_duo_module.DuoRegionKind
import nitro.nitro_fold_duo_module.DuoReservedRegion
import nitro.nitro_fold_duo_module.DuoState
import nitro.nitro_fold_duo_module.DuoVerticalBarEdge
import nitro.nitro_fold_duo_module.HybridNitroFoldDuoSpec

/// Native implementation of HybridNitroFoldDuoSpec.
///
/// The fold is real on Android: Jetpack WindowManager reports a
/// [FoldingFeature] with bounds, posture and whether it separates the display,
/// which is the same information UIKit gives as a reserved region. The hinge
/// angle comes from the hinge-angle sensor where the device has one.
///
/// The Liquid Glass bar is an iPhone Duo control with no Android counterpart,
/// so those calls are accepted and ignored rather than failing.
class NitroFoldDuoImpl : HybridNitroFoldDuoSpec {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val state = MutableStateFlow(UNAVAILABLE)

    private var layoutJob: Job? = null
    // Named apart from the spec's own `activity` property, which the bridge
    // populates from the plugin binding.
    private var boundActivity: Activity? = null
    private var folding: FoldingFeature? = null
    private var hingeAngle: Double? = null
    private var hingeSensor: HingeSensor? = null

    override fun currentState(): DuoState = state.value

    override val stateChanges: Flow<DuoState> = state.asStateFlow()

    override fun onActivityAttached(activity: Activity) {
        detach()
        boundActivity = activity

        layoutJob = scope.launch {
            WindowInfoTracker.getOrCreate(activity)
                .windowLayoutInfo(activity)
                .collect { info ->
                    folding = info.displayFeatures.filterIsInstance<FoldingFeature>()
                        .firstOrNull()
                    publish()
                }
        }

        hingeSensor = HingeSensor(activity) { degrees ->
            hingeAngle = Math.toRadians(degrees.toDouble())
            publish()
        }.also { it.start() }

        publish()
    }

    override fun onActivityDetached() {
        detach()
        state.value = UNAVAILABLE
    }

    private fun detach() {
        layoutJob?.cancel()
        layoutJob = null
        hingeSensor?.stop()
        hingeSensor = null
        boundActivity = null
        folding = null
        hingeAngle = null
    }

    private fun publish() {
        val activity = boundActivity ?: return
        val density = activity.resources.displayMetrics.density
        val fold = folding

        val regions = mutableListOf<DuoReservedRegion>()
        if (fold != null) {
            val bounds = fold.bounds
            regions += region(
                kind = DuoRegionKind.DIVISION,
                left = bounds.left / density,
                top = bounds.top / density,
                width = bounds.width() / density,
                height = bounds.height() / density,
                // A flat fold divides nothing, which is what `isSeparating`
                // already says.
                isActive = fold.isSeparating,
            )
            // A hinge that hides what is behind it occludes as well as divides.
            if (fold.occlusionType == FoldingFeature.OcclusionType.FULL) {
                regions += region(
                    kind = DuoRegionKind.OCCLUSION,
                    left = bounds.left / density,
                    top = bounds.top / density,
                    width = bounds.width() / density,
                    height = bounds.height() / density,
                    isActive = true,
                )
            }
        }

        state.value = DuoState(
            isSupported = true,
            hingeStatus = when (fold?.state) {
                FoldingFeature.State.FLAT -> DuoHingeStatus.FULLYOPEN
                FoldingFeature.State.HALF_OPENED -> DuoHingeStatus.PARTIALLYOPEN
                else -> DuoHingeStatus.UNKNOWN
            },
            // Android keeps its bars horizontal; there is no vertical strip.
            verticalBarEdge = DuoVerticalBarEdge.UNSPECIFIED,
            hingeAngle = hingeAngle,
            regions = regions,
            cornerInsets = cornerInsets(activity, density),
        )
    }

    /// What the display's rounded corners eat into each edge, so content at a
    /// corner is not clipped. The radii are only reported from API 31.
    private fun cornerInsets(activity: Activity, density: Float): DuoInsets {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return NO_INSETS
        val insets = activity.window?.decorView?.rootWindowInsets ?: return NO_INSETS

        fun radius(position: Int): Float =
            (insets.getRoundedCorner(position)?.radius ?: 0) / density

        return DuoInsets(
            left = maxOf(
                radius(RoundedCorner.POSITION_TOP_LEFT),
                radius(RoundedCorner.POSITION_BOTTOM_LEFT),
            ).toDouble(),
            top = maxOf(
                radius(RoundedCorner.POSITION_TOP_LEFT),
                radius(RoundedCorner.POSITION_TOP_RIGHT),
            ).toDouble(),
            right = maxOf(
                radius(RoundedCorner.POSITION_TOP_RIGHT),
                radius(RoundedCorner.POSITION_BOTTOM_RIGHT),
            ).toDouble(),
            bottom = maxOf(
                radius(RoundedCorner.POSITION_BOTTOM_LEFT),
                radius(RoundedCorner.POSITION_BOTTOM_RIGHT),
            ).toDouble(),
        )
    }

    private fun region(
        kind: DuoRegionKind,
        left: Float,
        top: Float,
        width: Float,
        height: Float,
        isActive: Boolean,
    ) = DuoReservedRegion(
        kind = kind,
        left = left.toDouble(),
        top = top.toDouble(),
        width = width.toDouble(),
        height = height.toDouble(),
        // WindowManager reports the fold without protective margins.
        marginLeft = 0.0,
        marginTop = 0.0,
        marginRight = 0.0,
        marginBottom = 0.0,
        isActive = isActive,
    )

    // The Liquid Glass bar is an iPhone Duo control; Android keeps its bars
    // horizontal, so these are accepted and ignored.
    override fun updateGlassCapsule(
        viewId: Long,
        symbols: List<String>,
        titles: List<String>,
        selectedIndex: Long,
        tint: Long,
        symbolPointSize: Double,
        isDark: Boolean,
    ) = Unit

    override fun updateGlassSurface(
        viewId: Long,
        cornerRadius: Double,
        tint: Long,
        isDark: Boolean,
    ) = Unit

    override fun setGlassCapsuleMenu(
        viewId: Long,
        buttonIndex: Long,
        titles: List<String>,
        symbols: List<String>,
    ) = Unit

    override val glassCapsulePresses: Flow<DuoBarPress> = emptyFlow()

    private companion object {
        val NO_INSETS = DuoInsets(left = 0.0, top = 0.0, right = 0.0, bottom = 0.0)

        val UNAVAILABLE = DuoState(
            isSupported = false,
            hingeStatus = DuoHingeStatus.UNKNOWN,
            verticalBarEdge = DuoVerticalBarEdge.UNSPECIFIED,
            hingeAngle = null,
            regions = emptyList(),
            cornerInsets = NO_INSETS,
        )
    }
}

/// Reads the hinge-angle sensor, where the device has one. WindowManager
/// reports the posture but not the angle.
private class HingeSensor(
    activity: Activity,
    private val onAngle: (Float) -> Unit,
) : SensorEventListener {

    private val manager =
        activity.getSystemService(Activity.SENSOR_SERVICE) as? SensorManager
    private val sensor =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)
        } else {
            null
        }

    fun start() {
        val sensor = sensor ?: return
        manager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    fun stop() {
        if (sensor != null) manager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        event.values.firstOrNull()?.let(onAngle)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
