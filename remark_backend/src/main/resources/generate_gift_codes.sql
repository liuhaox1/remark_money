-- 生成10000条不重复的8位数礼包码
-- 每个礼包码对应1年的3元/月套餐（plan_type=1, duration_months=12）

DELIMITER $$

CREATE PROCEDURE GenerateGiftCodes()
BEGIN
  DECLARE i INT DEFAULT 0;
  DECLARE code VARCHAR(8);
  DECLARE codeExists INT;
  
  WHILE i < 10000 DO
    -- 生成8位随机数字
    SET code = LPAD(FLOOR(RAND() * 100000000), 8, '0');
    
    -- 检查是否已存在
    SELECT COUNT(*) INTO codeExists FROM gift_code WHERE gift_code.code = code;
    
    -- 如果不存在，插入
    IF codeExists = 0 THEN
      INSERT INTO gift_code (
        code, 
        status, 
        plan_type, 
        duration_months, 
        expire_at,
        version
      ) VALUES (
        code,
        0,  -- 未使用
        1,  -- 3元/月套餐
        12, -- 12个月（1年）
        DATE_ADD(NOW(), INTERVAL 2 YEAR), -- 2年后过期
        0
      );
      SET i = i + 1;
    END IF;
  END WHILE;
END$$

DELIMITER ;

-- 执行存储过程生成礼包码
CALL GenerateGiftCodes();

-- 删除存储过程
DROP PROCEDURE IF EXISTS GenerateGiftCodes;

-- 验证生成的数量
SELECT COUNT(*) as total_codes FROM gift_code WHERE plan_type = 1 AND duration_months = 12;

