/* Licensed under Apache 2.0 (C) 2023 Firezone, Inc. */
package dev.firezone.android.core.data

import android.content.SharedPreferences
import dev.firezone.android.core.data.model.Config
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import javax.inject.Inject

internal class PreferenceRepositoryImpl
    @Inject
    constructor(
        private val coroutineDispatcher: CoroutineDispatcher,
        private val sharedPreferences: SharedPreferences,
    ) : PreferenceRepository {
        override fun getConfigSync(): Config =
            Config(
                accountId = sharedPreferences.getString(ACCOUNT_ID_KEY, null),
                token = sharedPreferences.getString(TOKEN_KEY, null),
            )

        override fun getConfig(): Flow<Config> =
            flow {
                emit(getConfigSync())
            }.flowOn(coroutineDispatcher)

        override fun saveAccountId(value: String): Flow<Unit> =
            flow {
                emit(
                    sharedPreferences
                        .edit()
                        .putString(ACCOUNT_ID_KEY, value)
                        .apply(),
                )
            }.flowOn(coroutineDispatcher)

        override fun saveToken(value: String): Flow<Unit> =
            flow {
                emit(
                    sharedPreferences
                        .edit()
                        .putString(TOKEN_KEY, value)
                        .apply(),
                )
            }.flowOn(coroutineDispatcher)

        override fun validateCsrfToken(value: String): Flow<Boolean> =
            flow {
                val token = sharedPreferences.getString(CSRF_KEY, "")
                emit(token == value)
            }.flowOn(coroutineDispatcher)

        override fun clearToken() {
            sharedPreferences.edit().apply {
                remove(CSRF_KEY)
                remove(TOKEN_KEY)
                apply()
            }
        }

        override fun clearAll() {
            sharedPreferences.edit().clear().apply()
        }

        companion object {
            private const val ACCOUNT_ID_KEY = "accountId"
            private const val TOKEN_KEY = "token"
            private const val CSRF_KEY = "csrf"
        }
    }
