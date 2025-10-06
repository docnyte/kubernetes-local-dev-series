package dev.docnyte.dataservice.exception;

import jakarta.persistence.EntityNotFoundException;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

/**
 * Global exception handler for the application.
 *
 * <p>Catches and handles exceptions thrown by controllers, providing consistent error responses.
 */
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

  /**
   * Handle EntityNotFoundException (404).
   *
   * @param ex the exception
   * @param request the web request
   * @return error response
   */
  @ExceptionHandler(EntityNotFoundException.class)
  public ResponseEntity<Map<String, Object>> handleEntityNotFoundException(
      EntityNotFoundException ex, WebRequest request) {
    if (log.isErrorEnabled()) {
      log.error("Entity not found: {}", ex.getMessage());
    }
    Map<String, Object> body = new HashMap<>();
    body.put("timestamp", LocalDateTime.now());
    body.put("status", HttpStatus.NOT_FOUND.value());
    body.put("error", "Not Found");
    body.put("message", ex.getMessage());
    body.put("path", request.getDescription(false).replace("uri=", ""));
    return new ResponseEntity<>(body, HttpStatus.NOT_FOUND);
  }

  /**
   * Handle IllegalArgumentException (400).
   *
   * @param ex the exception
   * @param request the web request
   * @return error response
   */
  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String, Object>> handleIllegalArgumentException(
      IllegalArgumentException ex, WebRequest request) {
    if (log.isErrorEnabled()) {
      log.error("Invalid argument: {}", ex.getMessage());
    }
    Map<String, Object> body = new HashMap<>();
    body.put("timestamp", LocalDateTime.now());
    body.put("status", HttpStatus.BAD_REQUEST.value());
    body.put("error", "Bad Request");
    body.put("message", ex.getMessage());
    body.put("path", request.getDescription(false).replace("uri=", ""));
    return new ResponseEntity<>(body, HttpStatus.BAD_REQUEST);
  }

  /**
   * Handle validation errors (400).
   *
   * @param ex the exception
   * @param request the web request
   * @return error response with field errors
   */
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<Map<String, Object>> handleValidationExceptions(
      MethodArgumentNotValidException ex, WebRequest request) {
    if (log.isErrorEnabled()) {
      log.error("Validation failed: {}", ex.getMessage());
    }

    Map<String, String> fieldErrors = new HashMap<>();
    ex.getBindingResult()
        .getAllErrors()
        .forEach(
            error -> {
              String fieldName = ((FieldError) error).getField();
              String errorMessage = error.getDefaultMessage();
              fieldErrors.put(fieldName, errorMessage);
            });

    Map<String, Object> body = new HashMap<>();
    body.put("timestamp", LocalDateTime.now());
    body.put("status", HttpStatus.BAD_REQUEST.value());
    body.put("error", "Validation Failed");
    body.put("message", "Invalid input parameters");
    body.put("fieldErrors", fieldErrors);
    body.put("path", request.getDescription(false).replace("uri=", ""));

    return new ResponseEntity<>(body, HttpStatus.BAD_REQUEST);
  }

  /**
   * Handle all other exceptions (500).
   *
   * @param ex the exception
   * @param request the web request
   * @return error response
   */
  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String, Object>> handleGlobalException(
      Exception ex, WebRequest request) {
    log.error("Internal server error", ex);
    Map<String, Object> body = new HashMap<>();
    body.put("timestamp", LocalDateTime.now());
    body.put("status", HttpStatus.INTERNAL_SERVER_ERROR.value());
    body.put("error", "Internal Server Error");
    body.put("message", "An unexpected error occurred");
    body.put("path", request.getDescription(false).replace("uri=", ""));
    return new ResponseEntity<>(body, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
