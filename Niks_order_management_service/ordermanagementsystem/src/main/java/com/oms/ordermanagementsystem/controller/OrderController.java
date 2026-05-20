package com.oms.ordermanagementsystem.controller;

import com.oms.ordermanagementsystem.model.Order;
import jakarta.validation.Valid;
import com.oms.ordermanagementsystem.service.OrderService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public Order createOrder(
            @Valid @RequestBody Order order,
            @RequestHeader("Authorization") String token) {
        return orderService.createOrder(order, token);
    }

    @GetMapping
    public List<Order> getOrders() {
        return orderService.getAllOrders();
    }
    @GetMapping("/{id}")
    public Order getOrder(@PathVariable Long id) {
        return orderService.getOrderById(id);
    }

    @DeleteMapping("/{id}")
    public String deleteOrder(@PathVariable Long id) {
        orderService.deleteOrder(id);
        return "Order deleted successfully";
    }
}