package com.remark.money.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

/**
 * Drop obvious scanner/path-traversal requests early to avoid noisy WARN logs from Spring's
 * ResourceHttpRequestHandler and reduce backend load.
 */
public class SuspiciousRequestFilter extends OncePerRequestFilter {

  private static final Logger log = LoggerFactory.getLogger(SuspiciousRequestFilter.class);

  @Override
  protected void doFilterInternal(
      HttpServletRequest request,
      HttpServletResponse response,
      FilterChain filterChain) throws ServletException, IOException {

    final String uri = request.getRequestURI();
    final String query = request.getQueryString();
    final String full = query == null ? uri : (uri + "?" + query);
    final String decoded = safeDecode(full);

    if (isSuspicious(full) || isSuspicious(decoded)) {
      final String remote = request.getRemoteAddr();
      final String ua = request.getHeader("User-Agent");
      log.warn("Blocked suspicious request uri={} remote={} ua={}", uri, remote, ua);
      writeJson(response, 400, "{\"success\":false,\"error\":\"invalid request\"}");
      return;
    }

    filterChain.doFilter(request, response);
  }

  private static String safeDecode(String value) {
    try {
      return URLDecoder.decode(value, StandardCharsets.UTF_8.name());
    } catch (Exception e) {
      return value;
    }
  }

  private static boolean isSuspicious(String value) {
    if (value == null || value.isEmpty()) return false;
    final String s = value.toLowerCase(Locale.ROOT);

    // Typical traversal payloads.
    if (s.contains("../") || s.contains("..\\") || s.contains("%2e%2e")) return true;
    // Vite-style file system probing: /@fs/../../...
    if (s.contains("/@fs/") || s.startsWith("@fs/") || s.contains("\\@fs\\")) return true;
    // Null byte or control chars in URL.
    if (s.contains("%00") || s.indexOf('\u0000') >= 0) return true;

    return false;
  }

  private static void writeJson(HttpServletResponse response, int status, String body)
      throws IOException {
    response.setStatus(status);
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    response.getWriter().write(body);
  }
}

