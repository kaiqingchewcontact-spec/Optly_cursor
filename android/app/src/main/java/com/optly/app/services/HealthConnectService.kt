package com.optly.app.services

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneOffset
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class HealthConnectService @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        val PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
        )
    }

    fun availability(): HealthConnectAvailability {
        val status = HealthConnectClient.getSdkStatus(context, "com.google.android.apps.healthdata")
        return when (status) {
            HealthConnectClient.SDK_AVAILABLE -> HealthConnectAvailability.Available
            HealthConnectClient.SDK_UNAVAILABLE -> HealthConnectAvailability.Unavailable
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                HealthConnectAvailability.ProviderUpdateRequired
            else -> HealthConnectAvailability.Unknown
        }
    }

    suspend fun readTodaySteps(): Long? = withContext(Dispatchers.IO) {
        if (availability() != HealthConnectAvailability.Available) return@withContext null
        val client = HealthConnectClient.getOrCreate(context)
        val now = Instant.now()
        val startOfDay = now.atZone(ZoneOffset.UTC).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant()
        val filter = TimeRangeFilter.between(startOfDay, now)
        val request = AggregateRequest(
            metrics = setOf(StepsRecord.COUNT_TOTAL),
            timeRangeFilter = filter,
        )
        runCatching {
            val response = client.aggregate(request)
            response[StepsRecord.COUNT_TOTAL]
        }.getOrNull()
    }

    suspend fun hasAllPermissions(): Boolean = withContext(Dispatchers.IO) {
        if (availability() != HealthConnectAvailability.Available) return@withContext false
        val client = HealthConnectClient.getOrCreate(context)
        val granted = client.permissionController.getGrantedPermissions()
        PERMISSIONS.all { it in granted }
    }
}

enum class HealthConnectAvailability {
    Available,
    Unavailable,
    ProviderUpdateRequired,
    Unknown,
}
