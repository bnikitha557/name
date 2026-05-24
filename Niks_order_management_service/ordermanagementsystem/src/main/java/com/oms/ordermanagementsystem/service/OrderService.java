package com.oms.ordermanagementsystem.service;

import com.oms.ordermanagementsystem.client.AuthClient;
import com.oms.ordermanagementsystem.model.Order;
import com.oms.ordermanagementsystem.repository.OrderRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final AuthClient authClient;
    private static final Logger logger = LoggerFactory.getLogger(OrderService.class);

    public OrderService(OrderRepository orderRepository, AuthClient authClient) {
        this.orderRepository = orderRepository;
        this.authClient = authClient;
    }

    public Order createOrder(Order order, String token) {
        Boolean isValid = authClient.validate(token);
        if (!Boolean.TRUE.equals(isValid)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized user");
        }
        logger.info("Creating order: {}", order);
        return orderRepository.save(order);
    }

    public List<Order> getAllOrders() {
        return orderRepository.findAll();
    }
    public Order getOrderById(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Order not found"));
    }

    public Order updateOrder(Long id, Order order, String token) {
        Boolean isValid = authClient.validate(token);
        if (!Boolean.TRUE.equals(isValid)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Unauthorized user");
        }
        Order existing = orderRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        existing.setProductName(order.getProductName());
        existing.setQuantity(order.getQuantity());
        existing.setPrice(order.getPrice());
        logger.info("Updating order {}: {}", id, existing);
        return orderRepository.save(existing);
    }

    public void deleteOrder(Long id) {
        orderRepository.deleteById(id);
    }
}