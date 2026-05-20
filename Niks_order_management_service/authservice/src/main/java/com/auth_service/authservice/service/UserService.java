package com.auth_service.authservice.service;

import com.auth_service.authservice.entity.User;
import com.auth_service.authservice.repository.UserRepository;
import com.auth_service.authservice.security.JwtUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    @Autowired
    private UserRepository repo;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private PasswordEncoder encoder;

    // SIGNUP
    public User register(User user) {
        user.setPassword(encoder.encode(user.getPassword()));
        return repo.save(user);
    }

    // LOGIN (NO Optional)
    public String login(String username, String password) {

        User user = repo.findByUsername(username);

        if (user != null) {

            if (encoder.matches(password, user.getPassword())) {
                return jwtUtil.generateToken(username);
            }

            return "Wrong Password";
        }

        return "User Not Found";
    }

    public Boolean validateToken(String token) {

        // simple validation for demo
        return token != null && token.startsWith("Bearer ");
    }
}