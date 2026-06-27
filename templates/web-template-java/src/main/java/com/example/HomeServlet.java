package com.example;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.net.InetAddress;

// Native Java web tech: the Servlet API (no framework). Runs on Tomcat.
@WebServlet(urlPatterns = {"/*"})
public class HomeServlet extends HttpServlet {

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

        resp.setContentType("text/html; charset=utf-8");
        resp.getWriter().write(
            "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">" +
            "<title>web-template-java</title>" +
            "<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>" +
            "</head><body><h1>web-template-java</h1>" +
            "<p>Hello from a Java Servlet server-rendered page.</p>" +
            "<p>Host: <code>" + host + "</code></p></body></html>");
    }
}
