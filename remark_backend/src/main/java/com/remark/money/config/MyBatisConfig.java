package com.remark.money.config;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.Configuration;

@Configuration
@MapperScan("com.remark.money.mapper")
public class MyBatisConfig {
  // 这里目前不需要额外配置，MapperScan 负责扫描 mapper 接口
}

