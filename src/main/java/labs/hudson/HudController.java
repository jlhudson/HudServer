package labs.hudson;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HudController {

    @GetMapping("/hello")
    public String sayHello() {
        return "Hello from your Raspberry Pi Spring Boot Application!";
    }
}