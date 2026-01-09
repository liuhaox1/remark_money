package com.remark.money.controller;

import com.remark.money.entity.Book;
import com.remark.money.entity.BookMemberProfile;
import com.remark.money.service.BookService;
import com.remark.money.util.JwtUtil;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import javax.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/book")
public class BookController {

  private final BookService bookService;
  private final JwtUtil jwtUtil;

  public BookController(BookService bookService, JwtUtil jwtUtil) {
    this.bookService = bookService;
    this.jwtUtil = jwtUtil;
  }

  @PostMapping("/create-multi")
  public Book createMulti(@RequestBody Map<String, String> body, HttpServletRequest request) {
    Long userId = getUserId(request);
    String name = body.getOrDefault("name", "多人账本");
    return bookService.createMultiBook(userId, name);
  }

  @PostMapping("/refresh-invite")
  public Book refreshInvite(@RequestBody Map<String, Object> body, HttpServletRequest request) {
    getUserId(request); // ensure logged in
    Long bookId = ((Number) body.get("bookId")).longValue();
    return bookService.refreshInvite(bookId);
  }

  @PostMapping("/join")
  public Book join(@RequestBody Map<String, String> body, HttpServletRequest request) {
    Long userId = getUserId(request);
    String code = body.get("code");
    if (!StringUtils.hasText(code) || code.length() != 8) {
      throw new IllegalArgumentException("邀请码格式不正确");
    }
    return bookService.joinByInvite(userId, code);
  }

  @GetMapping("/list")
  public List<Book> list(HttpServletRequest request) {
    Long userId = getUserId(request);
    return bookService.listByUser(userId);
  }

  @GetMapping("/members")
  public List<BookMemberProfile> members(
      @RequestParam("bookId") Long bookId, HttpServletRequest request) {
    Long userId = getUserId(request);
    return bookService.listMembers(userId, bookId);
  }

  private Long getUserId(HttpServletRequest request) {
    String auth = request.getHeader("Authorization");
    if (!StringUtils.hasText(auth) || !auth.startsWith("Bearer ")) {
      throw new IllegalArgumentException("未登录");
    }
    String token = auth.substring(7);
    return jwtUtil.parseUserId(token);
  }
}

