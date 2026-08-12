package com.gymstreak.gym_streak

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget showing the current gym streak.
 *
 * Renders only what the app last wrote into shared storage — a widget process
 * cannot run Dart or reach Supabase. StreakHomeWidget on the Flutter side is
 * what keeps these values fresh; see
 * lib/features/home/widgets/streak_home_widget.dart.
 *
 * The key names below must stay in step with StreakWidgetKeys there.
 */
class StreakWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                val current = data.getInt("current_streak", 0)
                val best = data.getInt("best_streak", 0)

                setTextViewText(R.id.streak_count, current.toString())
                setTextViewText(
                    R.id.streak_label,
                    if (current == 1) "day streak" else "days streak"
                )
                setTextViewText(R.id.streak_best, "Best $best")

                // Tapping opens the app straight at the workout picker.
                // Deliberately not a background write: choosing the workout
                // type needs the user, and a background isolate that fails
                // silently is worse than one extra tap.
                setOnClickPendingIntent(
                    R.id.streak_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("gymstreak://log"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
