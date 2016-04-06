package au.org.howe.fourstate;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.ModelAndView;

@Controller
public class DesktopController {
    @RequestMapping(value = "/desktop", method = RequestMethod.GET)
    public ModelAndView barcode() {
        return new ModelAndView("desktop");
    }
}
