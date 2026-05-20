package com.auth_service.authservice.controller;



import com.auth_service.authservice.entity.User;
import com.auth_service.authservice.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
public class AuthController {

    @Autowired
    private UserService service;

    @PostMapping("/signup")
    public User signup(@RequestBody User user) {
        return service.register(user);
    }

    @PostMapping("/login")
    public String login(@RequestBody User user) {
        return service.login(user.getUsername(), user.getPassword());

    }
    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    // INTER-SERVICE COMMUNICATION ENDPOINT
    @GetMapping("/validate")
    public Boolean validateToken(@RequestHeader("Authorization") String token) {

        // Simple demo logic (you can later replace with JWT validation)
        return service.validateToken(token);
    }

}