package com.remark.money.controller;

import com.remark.money.entity.User;
import com.remark.money.mapper.UserMapper;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {

  private final UserMapper userMapper;

  public UserController(UserMapper userMapper) {
    this.userMapper = userMapper;
  }

  @GetMapping("/{id}")
  public User getById(@PathVariable("id") Long id) {
    return userMapper.findById(id);
  }
}

