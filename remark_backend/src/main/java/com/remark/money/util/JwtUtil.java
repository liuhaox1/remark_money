package com.remark.money.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtUtil {

  @Value("${auth.jwt-secret}")
  private String secret;

  @Value("${auth.jwt-expiration-seconds}")
  private long expirationSeconds;

  public String generateToken(Long userId) {
    Date now = new Date();
    Date expiry = new Date(now.getTime() + expirationSeconds * 1000);
    return Jwts.builder()
        .setSubject(String.valueOf(userId))
        .setIssuedAt(now)
        .setExpiration(expiry)
        .signWith(SignatureAlgorithm.HS256, secret)
        .compact();
  }

  public Long parseUserId(String token) {
    Claims claims = Jwts.parser()
        .setSigningKey(secret)
        .parseClaimsJws(token)
        .getBody();
    return Long.valueOf(claims.getSubject());
  }
}

