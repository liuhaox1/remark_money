package com.remark.money.service;

import com.remark.money.entity.Book;
import com.remark.money.entity.BookMember;
import com.remark.money.entity.BookMemberProfile;
import com.remark.money.mapper.BookMapper;
import com.remark.money.mapper.BookMemberMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.util.Collections;
import java.util.List;

@Service
public class BookService {

  private static final Logger log = LoggerFactory.getLogger(BookService.class);

  private final BookMapper bookMapper;
  private final BookMemberMapper bookMemberMapper;
  private final SecureRandom random = new SecureRandom();

  public BookService(BookMapper bookMapper, BookMemberMapper bookMemberMapper) {
    this.bookMapper = bookMapper;
    this.bookMemberMapper = bookMemberMapper;
  }

  public Book createMultiBook(Long userId, String name) {
    Book book = new Book();
    book.setOwnerId(userId);
    book.setName(name);
    book.setIsMulti(true);
    book.setStatus(1);

    String invite = generateInviteCode();
    book.setInviteCode(invite);
    int retries = 3;
    while (retries-- > 0) {
      try {
        bookMapper.insert(book);
        addMember(book.getId(), userId, "owner");
        return book;
      } catch (DuplicateKeyException e) {
        invite = generateInviteCode();
        book.setInviteCode(invite);
      }
    }
    throw new IllegalStateException("邀请码生成失败，请重试");
  }

  public Book refreshInvite(Long bookId) {
    String invite = generateInviteCode();
    int retries = 3;
    while (retries-- > 0) {
      try {
        int updated = bookMapper.updateInviteCode(bookId, invite);
        if (updated > 0) {
          return bookMapper.findByInviteCode(invite);
        }
      } catch (DuplicateKeyException e) {
        invite = generateInviteCode();
      }
    }
    throw new IllegalStateException("邀请码生成失败，请稍后重试");
  }

  public Book joinByInvite(Long userId, String inviteCode) {
    Book book = bookMapper.findByInviteCode(inviteCode);
    if (book == null || book.getStatus() == null || book.getStatus() != 1) {
      throw new IllegalArgumentException("邀请码无效或账本不可用");
    }
    try {
      addMember(book.getId(), userId, "editor");
    } catch (DuplicateKeyException e) {
      // 已加入则忽略
    }
    return book;
  }

  public List<Book> listByUser(Long userId) {
    return bookMapper.listByUser(userId);
  }

  public List<BookMemberProfile> listMembers(Long userId, Long bookId) {
    if (bookId == null) {
      log.warn("listMembers missing bookId userId={}", userId);
      return Collections.emptyList();
    }
    BookMember me = bookMemberMapper.find(bookId, userId);
    if (me == null || me.getStatus() == null || me.getStatus() != 1) {
      log.warn("listMembers no permission userId={} bookId={}", userId, bookId);
      return Collections.emptyList();
    }
    return bookMemberMapper.listProfilesByBook(bookId);
  }

  private void addMember(Long bookId, Long userId, String role) {
    BookMember member = new BookMember();
    member.setBookId(bookId);
    member.setUserId(userId);
    member.setRole(role);
    member.setStatus(1);
    bookMemberMapper.insert(member);
  }

  private String generateInviteCode() {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < 8; i++) {
      sb.append(random.nextInt(10));
    }
    return sb.toString();
  }
}

