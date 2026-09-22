package com.yogesh.enterprise.orderservice.controller;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/test")
public class RetryTestController {
    @GetMapping("/retry")
    @ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
    public String retryTest() {
        System.out.println(">>> Retry test endpoint invoked");
        return "Temporary failure for retry demonstration";
    }
}
