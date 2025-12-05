package com.remark.money.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/health")
public class HealthController {

  @GetMapping
  public Map<String, Object> health() {
    Map<String, Object> result = new HashMap<>();
    result.put("status", "OK");
    result.put("timestamp", Instant.now().toString());
    return result;
  }
}

