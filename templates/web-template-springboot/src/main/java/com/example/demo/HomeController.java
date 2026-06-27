package com.example.demo;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.net.InetAddress;
import java.net.UnknownHostException;

// Server-rendered web counterpart of svc-template-java (which returns JSON).
@Controller
public class HomeController {

    @GetMapping("/health")
    @ResponseBody
    public String health() {
        return "ok";
    }

    // Renders templates/index.html via Thymeleaf.
    @GetMapping("/")
    public String index(Model model) {
        String host = "unknown";
        try {
            host = InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException ignored) {
        }
        model.addAttribute("host", host);
        return "index";
    }
}
