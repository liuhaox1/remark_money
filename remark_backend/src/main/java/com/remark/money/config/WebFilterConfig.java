package com.remark.money.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class WebFilterConfig {

  @Bean
  public FilterRegistrationBean<SuspiciousRequestFilter> suspiciousRequestFilter() {
    FilterRegistrationBean<SuspiciousRequestFilter> bean = new FilterRegistrationBean<>();
    bean.setFilter(new SuspiciousRequestFilter());
    bean.setOrder(1); // run early
    return bean;
  }
}

