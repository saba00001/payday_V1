package com.example.payday

import android.app.KeyguardManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ReminderActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Re-check lock state inside the activity.
        // There is a race window between AlarmReceiver's check and this
        // activity starting — the phone could lock in between.
        val keyguardManager = try {
            getSystemService(KEYGUARD_SERVICE) as? KeyguardManager
        } catch (_: Exception) { null }

        val isLocked = keyguardManager?.isKeyguardLocked ?: true

        if (isLocked) {
            // Phone is locked — do NOT show over lock screen. Finish immediately.
            // The notification shown by AlarmReceiver is the correct fallback.
            finish()
            return
        }

        // Phone is unlocked — safe to show full-screen reminder UI.
        setupWindowFlags()

        setContent {
            ReminderScreen(
                onWorked = {
                    saveActionResult("worked")
                    launchMainApp()
                    finish()
                },
                onNotWorked = {
                    saveActionResult("not_worked")
                    finish()
                }
            )
        }
    }

    /**
     * Configure window flags for the unlocked-phone case.
     * - setShowWhenLocked(false): explicitly do NOT show over lock screen.
     * - setTurnScreenOn(true): wake the screen if it was off but unlocked
     *   (e.g. trusted environment with smart lock).
     * FLAG_SHOW_WHEN_LOCKED is intentionally NOT set to avoid covering
     * the Android lock screen on any device.
     */
    private fun setupWindowFlags() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
                // Explicitly clear SHOW_WHEN_LOCKED on older APIs.
                @Suppress("DEPRECATION")
                window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            }
        } catch (_: Exception) {
            // Window flag errors must not crash the activity.
        }
    }

    /**
     * Persist the user's action so Flutter can read it on next app launch.
     * Uses the same SharedPreferences namespace as Flutter.
     */
    private fun saveActionResult(result: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit()
                .putString("flutter.payday_reminder_action_result", result)
                .apply()
        } catch (_: Exception) {
            // Prefs write failure must not crash the activity.
        }
    }

    /**
     * Launch the main Flutter app so the user can see the result of their action.
     * The "reminder_action" extra is passed so MainActivity can handle it.
     */
    private fun launchMainApp() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("reminder_action", "worked")
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Activity launch failure must not crash the reminder activity.
        }
    }
}

@Composable
fun ReminderScreen(
    onWorked: () -> Unit,
    onNotWorked: () -> Unit
) {
    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
    val currentTime = timeFormat.format(Date())

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF050A18),
                        Color(0xFF0A1628),
                        Color(0xFF050A18)
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        // Ambient orb
        Box(
            modifier = Modifier
                .size(300.dp)
                .offset(y = (-80).dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            Color(0xFF00D4FF).copy(alpha = 0.08f),
                            Color.Transparent
                        )
                    ),
                    shape = RoundedCornerShape(50)
                )
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 32.dp)
        ) {
            // Logo mark
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(
                        Brush.linearGradient(
                            colors = listOf(Color(0xFF00D4FF), Color(0xFF7B61FF))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "₾",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }

            Text(
                text = "PayDay",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Color(0xFF00D4FF).copy(alpha = 0.8f),
                letterSpacing = 3.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = currentTime,
                fontSize = 48.sp,
                fontWeight = FontWeight.Light,
                color = Color.White.copy(alpha = 0.9f)
            )

            Text(
                text = "იმუშავე დღეს?",
                fontSize = 22.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(8.dp))

            // YES button — ვიმუშავე
            Button(
                onClick = onWorked,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF00D4FF).copy(alpha = 0.15f)
                )
            ) {
                Text(
                    text = "✓  კი, ვიმუშავე",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF00D4FF)
                )
            }

            // NO button — არ მიმუშავია
            OutlinedButton(
                onClick = onNotWorked,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Color.White.copy(alpha = 0.6f)
                ),
                border = androidx.compose.foundation.BorderStroke(
                    1.dp,
                    Color.White.copy(alpha = 0.15f)
                )
            ) {
                Text(
                    text = "არა, არ მიმუშავია",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Normal,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }
    }
}
