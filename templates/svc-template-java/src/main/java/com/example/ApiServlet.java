package com.example;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.net.InetAddress;

// Native Java web tech: the Servlet API (no framework). Runs on Tomcat.
@WebServlet(urlPatterns = {"/*"})
public class ApiServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        if ("/health".equals(req.getPathInfo())) {
            resp.setContentType("text/plain");
            resp.getWriter().write("ok");
            return;
        }

        String host;
        try {
            host = InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            host = "unknown";
        }

        // Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
        resp.setContentType("application/json");
        resp.getWriter().write(
            "{\"service\":\"svc-template-java\"," +
            "\"message\":\"Hello from Java Servlet\"," +
            "\"hostname\":\"" + host + "\"}");
    }
}
