package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/health")
    public String health() {
        return "ok";
    }

    // Backing services on lds-network: mysql:3306, postgres:5432, redis:6379,
    // kafka-broker:9092 ...
    @GetMapping("/")
    public Map<String, String> root() {
        String host = "unknown";
        try {
            host = InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException ignored) {
        }
        return Map.of(
            "service", "java",
            "message", "Hello from Java + Spring Boot",
            "hostname", host
        );
    }
}
