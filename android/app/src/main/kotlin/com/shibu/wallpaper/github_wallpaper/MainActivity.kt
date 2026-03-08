package com.shibu.wallpaper.github_wallpaper

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shibu.wallpaper/github"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getClientId" -> {
                    result.success(BuildConfig.GITHUB_CLIENT_ID)
                }
                "getClientSecret" -> {
                    result.success(BuildConfig.GITHUB_CLIENT_SECRET)
                }
                "getRedirectUri" -> {
                    result.success(BuildConfig.GITHUB_REDIRECT_URI)
                }
                "setWallpaper" -> {
                    val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                    intent.putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                        ComponentName(this, WallpaperService::class.java))
                    startActivity(intent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
