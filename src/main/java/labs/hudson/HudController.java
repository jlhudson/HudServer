package labs.hudson;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.lang.management.ManagementFactory;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HudController {

    @GetMapping("/hello")
    public String sayHello() {
        return "Hello from your Raspberry Pi Spring Boot Application!";
    }

    @GetMapping("/api/status")
    public Map<String, Object> getStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("status", "UP");
        status.put("timestamp", LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        status.put("uptime", ManagementFactory.getRuntimeMXBean().getUptime());
        status.put("application", "HudServer");
        status.put("version", "0.0.1-SNAPSHOT");
        return status;
    }

    @GetMapping("/api/time")
    public Map<String, String> getCurrentTime() {
        LocalDateTime now = LocalDateTime.now();
        Map<String, String> timeInfo = new HashMap<>();
        timeInfo.put("currentTime", now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        timeInfo.put("formatted", now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        timeInfo.put("timezone", System.getProperty("user.timezone"));
        return timeInfo;
    }

    @GetMapping("/api/system")
    public Map<String, Object> getSystemInfo() {
        Map<String, Object> systemInfo = new HashMap<>();
        Runtime runtime = Runtime.getRuntime();

        systemInfo.put("javaVersion", System.getProperty("java.version"));
        systemInfo.put("javaVendor", System.getProperty("java.vendor"));
        systemInfo.put("osName", System.getProperty("os.name"));
        systemInfo.put("osVersion", System.getProperty("os.version"));
        systemInfo.put("osArch", System.getProperty("os.arch"));
        systemInfo.put("totalMemory", runtime.totalMemory());
        systemInfo.put("freeMemory", runtime.freeMemory());
        systemInfo.put("maxMemory", runtime.maxMemory());
        systemInfo.put("processors", runtime.availableProcessors());

        return systemInfo;
    }

    @GetMapping("/api/echo/{message}")
    public Map<String, String> echoMessage(@PathVariable String message) {
        Map<String, String> response = new HashMap<>();
        response.put("originalMessage", message);
        response.put("echoed", "Echo: " + message);
        response.put("timestamp", LocalDateTime.now().toString());
        return response;
    }

    @GetMapping("/api/greet")
    public Map<String, String> greetUser(@RequestParam(defaultValue = "World") String name) {
        Map<String, String> response = new HashMap<>();
        response.put("greeting", "Hello, " + name + "!");
        response.put("message", "Greetings from your Raspberry Pi HudServer!");
        response.put("timestamp", LocalDateTime.now().toString());
        return response;
    }

    @GetMapping("/api/health")
    public Map<String, Object> healthCheck() {
        Map<String, Object> health = new HashMap<>();
        health.put("status", "healthy");
        health.put("checks", Map.of(
                "database", "not configured",
                "memory", "OK",
                "disk", "OK"
        ));
        health.put("timestamp", LocalDateTime.now());
        return health;
    }
}

// Separate controller for Thymeleaf endpoints
@Controller
class HudViewController {

    @GetMapping("/dashboard")
    public String dashboard(Model model) {
        // Add data to the model for the template
        model.addAttribute("title", "HudServer Dashboard");
        model.addAttribute("message", "Welcome to your Raspberry Pi HudServer!");
        model.addAttribute("currentTime", LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")));
        model.addAttribute("javaVersion", System.getProperty("java.version"));
        model.addAttribute("osName", System.getProperty("os.name"));
        model.addAttribute("osArch", System.getProperty("os.arch"));

        Runtime runtime = Runtime.getRuntime();
        long totalMemory = runtime.totalMemory();
        long freeMemory = runtime.freeMemory();
        long usedMemory = totalMemory - freeMemory;

        model.addAttribute("totalMemory", formatBytes(totalMemory));
        model.addAttribute("usedMemory", formatBytes(usedMemory));
        model.addAttribute("freeMemory", formatBytes(freeMemory));

        return "dashboard"; // This will look for src/main/resources/templates/dashboard.html
    }

    private String formatBytes(long bytes) {
        if (bytes < 1024) return bytes + " B";
        int exp = (int) (Math.log(bytes) / Math.log(1024));
        String pre = "KMGTPE".charAt(exp - 1) + "";
        return String.format("%.1f %sB", bytes / Math.pow(1024, exp), pre);
    }
}