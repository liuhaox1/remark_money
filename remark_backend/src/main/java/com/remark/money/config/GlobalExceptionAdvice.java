package com.remark.money.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MultipartException;

import javax.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionAdvice {

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionAdvice.class);

  @ExceptionHandler(MultipartException.class)
  public ResponseEntity<Map<String, Object>> handleMultipartException(
      MultipartException ex, HttpServletRequest request) {
    final String uri = request != null ? request.getRequestURI() : "";
    final String remote = request != null ? request.getRemoteAddr() : "";
    log.warn("Multipart request parse failed uri={} remote={} message={}", uri, remote, ex.getMessage());

    final Map<String, Object> body = new HashMap<>();
    body.put("success", false);
    body.put("error", "invalid multipart request");
    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
  }
}

