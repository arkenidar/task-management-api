package com.arkenidar

import com.kborowy.authprovider.firebase.firebase
import io.ktor.client.*
import io.ktor.client.engine.apache.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.auth.*
import io.ktor.server.plugins.csrf.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.sessions.*
import java.io.File
import kotlinx.serialization.Serializable

fun Application.configureSecurity() {
    install(Authentication) {
        oauth("auth-oauth-google") {
            urlProvider = { "http://localhost:8080/callback" }
            providerLookup = {
                OAuthServerSettings.OAuth2ServerSettings(
                    name = "google",
                    authorizeUrl = "https://accounts.google.com/o/oauth2/auth",
                    accessTokenUrl = "https://accounts.google.com/o/oauth2/token",
                    requestMethod = HttpMethod.Post,
                    clientId = System.getenv("GOOGLE_CLIENT_ID"),
                    clientSecret = System.getenv("GOOGLE_CLIENT_SECRET"),
                    defaultScopes = listOf("https://www.googleapis.com/auth/userinfo.profile")
                )
            }
            client = HttpClient(Apache)
        }
        // Comment out Firebase authentication until proper admin file is configured
        /*
        firebase {
            adminFile = File("path/to/admin/file.json")
            realm = "My Server"
            validate { token ->
                MyAuthenticatedUser(id = token.uid)
            }
        }
        */
    }
    install(CSRF) {
        // tests Origin is an expected value
        allowOrigin("http://localhost:8080")
    
        // tests Origin matches Host header
        originMatchesHost()
    
        // custom header checks
        checkHeader("X-CSRF-Token")
    }
    install(Sessions) {
        cookie<MySession>("MY_SESSION") {
            cookie.extensions["SameSite"] = "lax"
        }
    }
    routing {
        authenticate("auth-oauth-google") {
            get("login") {
                // OAuth will automatically redirect to Google's authorization page
                // No explicit redirect needed - Ktor handles this automatically
            }
        
            get("/callback") {
                val principal: OAuthAccessTokenResponse.OAuth2? = call.authentication.principal()
                if (principal != null) {
                    // Store authenticated user session
                    val session = call.sessions.get<MySession>() ?: MySession()
                    call.sessions.set(session.copy(count = session.count + 1))
                    call.respondRedirect("/hello")
                } else {
                    call.respondRedirect("/login")
                }
            }
        }
        get("/session/increment") {
            val session = call.sessions.get<MySession>() ?: MySession()
            call.sessions.set(session.copy(count = session.count + 1))
            call.respondText("Counter is ${session.count}. Refresh to increment.")
        }
    }
}

@Serializable
data class MySession(val count: Int = 0)

data class MyAuthenticatedUser(val id: String)
