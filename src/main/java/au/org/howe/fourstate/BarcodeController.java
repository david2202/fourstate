package au.org.howe.fourstate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.ModelAndView;

import java.util.Map;

@Controller
public class BarcodeController {

    @Autowired
    private Integer httpPort;

    @RequestMapping(value = "/barcode", method = RequestMethod.GET)
    public ModelAndView barcode() {
        ModelAndView mav = new ModelAndView("barcode");
        mav.addObject("httpPort", httpPort);
        return mav;
    }
}
