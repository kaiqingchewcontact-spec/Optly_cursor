package com.optly.app.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import com.optly.app.models.DailyBriefing
import com.optly.app.models.Habit
import com.optly.app.models.InsightCard
import com.optly.app.models.Subscription
import com.optly.app.models.User
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Entity(tableName = "user_profile")
data class UserProfileEntity(
    @PrimaryKey val id: String,
    val payload: String,
)

@Entity(tableName = "daily_briefing")
data class DailyBriefingEntity(
    @PrimaryKey val dateEpochDay: Long,
    val payload: String,
)

@Entity(tableName = "insights")
data class InsightEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val payload: String,
)

@Entity(tableName = "habits")
data class HabitEntity(
    @PrimaryKey val id: String,
    val payload: String,
)

@Entity(tableName = "subscriptions")
data class SubscriptionEntity(
    @PrimaryKey val id: String,
    val payload: String,
)

@Dao
interface UserProfileDao {
    @Query("SELECT * FROM user_profile WHERE id = :id LIMIT 1")
    fun observeUser(id: String): Flow<UserProfileEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: UserProfileEntity)
}

@Dao
interface DailyBriefingDao {
    @Query("SELECT * FROM daily_briefing WHERE dateEpochDay = :day LIMIT 1")
    suspend fun getForDay(day: Long): DailyBriefingEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: DailyBriefingEntity)
}

@Dao
interface InsightDao {
    @Query("SELECT * FROM insights ORDER BY id")
    fun observeInsights(): Flow<List<InsightEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<InsightEntity>)

    @Query("DELETE FROM insights")
    suspend fun clear()
}

@Dao
interface HabitDao {
    @Query("SELECT * FROM habits ORDER BY id")
    fun observeHabits(): Flow<List<HabitEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<HabitEntity>)
}

@Dao
interface SubscriptionDao {
    @Query("SELECT * FROM subscriptions ORDER BY id")
    fun observeSubscriptions(): Flow<List<SubscriptionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<SubscriptionEntity>)
}

@Database(
    entities = [
        UserProfileEntity::class,
        DailyBriefingEntity::class,
        InsightEntity::class,
        HabitEntity::class,
        SubscriptionEntity::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class OptlyDatabase : RoomDatabase() {
    abstract fun userProfileDao(): UserProfileDao
    abstract fun dailyBriefingDao(): DailyBriefingDao
    abstract fun insightDao(): InsightDao
    abstract fun habitDao(): HabitDao
    abstract fun subscriptionDao(): SubscriptionDao
}

object EntityMappers {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun User.toEntity(): UserProfileEntity =
        UserProfileEntity(id = id, payload = json.encodeToString(this))

    fun UserProfileEntity.toUser(): User = json.decodeFromString(payload)

    fun DailyBriefing.toEntity(): DailyBriefingEntity =
        DailyBriefingEntity(dateEpochDay = dateEpochDay, payload = json.encodeToString(this))

    fun DailyBriefingEntity.toBriefing(): DailyBriefing = json.decodeFromString(payload)

    fun InsightCard.toEntity(): InsightEntity =
        InsightEntity(id = id, kind = kind.name, payload = json.encodeToString(this))

    fun InsightEntity.toInsight(): InsightCard = json.decodeFromString(payload)

    fun Habit.toEntity(): HabitEntity =
        HabitEntity(id = id, payload = json.encodeToString(this))

    fun HabitEntity.toHabit(): Habit = json.decodeFromString(payload)

    fun Subscription.toEntity(): SubscriptionEntity =
        SubscriptionEntity(id = id, payload = json.encodeToString(this))

    fun SubscriptionEntity.toSubscription(): Subscription = json.decodeFromString(payload)
}
