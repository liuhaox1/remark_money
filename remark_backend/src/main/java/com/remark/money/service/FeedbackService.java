package com.remark.money.service;

import com.remark.money.entity.Feedback;
import com.remark.money.mapper.FeedbackMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class FeedbackService {

  private final FeedbackMapper feedbackMapper;

  public FeedbackService(FeedbackMapper feedbackMapper) {
    this.feedbackMapper = feedbackMapper;
  }

  public Long submit(Feedback feedback) {
    feedbackMapper.insert(feedback);
    return feedback.getId();
  }

  public List<Feedback> listRecent(int limit) {
    return feedbackMapper.listRecent(limit);
  }
}

