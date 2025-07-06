package com.arkenidar

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.serialization.Serializable
import java.util.concurrent.atomic.AtomicInteger

@Serializable
data class Task(
    val id: Int,
    val title: String,
    val description: String,
    val completed: Boolean = false
)

@Serializable
data class CreateTaskRequest(
    val title: String,
    val description: String
)

@Serializable
data class UpdateTaskRequest(
    val title: String? = null,
    val description: String? = null,
    val completed: Boolean? = null
)

@Serializable
data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val message: String? = null
)

@Serializable
data class ApiInfo(
    val name: String,
    val version: String,
    val description: String,
    val endpoints: Map<String, String>
)

fun Application.configureRouting() {
    val tasks = mutableListOf<Task>()
    val taskIdCounter = AtomicInteger(1)

    routing {
        // Root endpoint
        get("/") {
            call.respondText("Hello World!")
        }

        // API info endpoint (replaces HTML home page)
        get("/home") {
            call.respond(
                HttpStatusCode.OK,
                ApiResponse(
                    success = true,
                    data = ApiInfo(
                        name = "Task Management API",
                        version = "1.0.0",
                        description = "A simple task management API for creating, reading, updating, and deleting tasks",
                        endpoints = mapOf(
                            "Swagger UI" to "/openapi",
                            "All Tasks" to "/api/tasks",
                            "Health Check" to "/api/health",
                            "API Info" to "/home"
                        )
                    ),
                    message = "Welcome to the Task Management API"
                )
            )
        }

        // API routes
        route("/api") {
            // Health check endpoint
            get("/health") {
                call.respond(
                    HttpStatusCode.OK,
                    ApiResponse(
                        success = true,
                        data = mapOf("status" to "healthy", "timestamp" to System.currentTimeMillis()),
                        message = "Service is running"
                    )
                )
            }

            // Task management endpoints
            route("/tasks") {
                // Get all tasks
                get {
                    call.respond(
                        HttpStatusCode.OK,
                        ApiResponse(success = true, data = tasks)
                    )
                }

                // Get task by ID
                get("/{id}") {
                    val id = call.parameters["id"]?.toIntOrNull()
                    if (id == null) {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            ApiResponse<Nothing>(success = false, message = "Invalid task ID")
                        )
                        return@get
                    }

                    val task = tasks.find { it.id == id }
                    if (task == null) {
                        call.respond(
                            HttpStatusCode.NotFound,
                            ApiResponse<Nothing>(success = false, message = "Task not found")
                        )
                        return@get
                    }

                    call.respond(
                        HttpStatusCode.OK,
                        ApiResponse(success = true, data = task)
                    )
                }

                // Create new task
                post {
                    try {
                        val request = call.receive<CreateTaskRequest>()
                        val newTask = Task(
                            id = taskIdCounter.getAndIncrement(),
                            title = request.title,
                            description = request.description
                        )
                        tasks.add(newTask)

                        call.respond(
                            HttpStatusCode.Created,
                            ApiResponse(success = true, data = newTask, message = "Task created successfully")
                        )
                    } catch (ex: Exception) {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            ApiResponse<Nothing>(success = false, message = "Invalid request body: ${ex.message}")
                        )
                    }
                }

                // Update task
                put("/{id}") {
                    val id = call.parameters["id"]?.toIntOrNull()
                    if (id == null) {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            ApiResponse<Nothing>(success = false, message = "Invalid task ID")
                        )
                        return@put
                    }

                    val taskIndex = tasks.indexOfFirst { it.id == id }
                    if (taskIndex == -1) {
                        call.respond(
                            HttpStatusCode.NotFound,
                            ApiResponse<Nothing>(success = false, message = "Task not found")
                        )
                        return@put
                    }

                    try {
                        val request = call.receive<UpdateTaskRequest>()
                        val currentTask = tasks[taskIndex]
                        val updatedTask = currentTask.copy(
                            title = request.title ?: currentTask.title,
                            description = request.description ?: currentTask.description,
                            completed = request.completed ?: currentTask.completed
                        )
                        tasks[taskIndex] = updatedTask

                        call.respond(
                            HttpStatusCode.OK,
                            ApiResponse(success = true, data = updatedTask, message = "Task updated successfully")
                        )
                    } catch (ex: Exception) {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            ApiResponse<Nothing>(success = false, message = "Invalid request body: ${ex.message}")
                        )
                    }
                }

                // Delete task
                delete("/{id}") {
                    val id = call.parameters["id"]?.toIntOrNull()
                    if (id == null) {
                        call.respond(
                            HttpStatusCode.BadRequest,
                            ApiResponse<Nothing>(success = false, message = "Invalid task ID")
                        )
                        return@delete
                    }

                    val removed = tasks.removeIf { it.id == id }
                    if (!removed) {
                        call.respond(
                            HttpStatusCode.NotFound,
                            ApiResponse<Nothing>(success = false, message = "Task not found")
                        )
                        return@delete
                    }

                    call.respond(
                        HttpStatusCode.OK,
                        ApiResponse<Nothing>(success = true, message = "Task deleted successfully")
                    )
                }
            }
        }
    }
}
