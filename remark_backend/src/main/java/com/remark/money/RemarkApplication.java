package com.remark.money;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class RemarkApplication {

  public static void main(String[] args) {
    SpringApplication.run(RemarkApplication.class, args);
  }
}
