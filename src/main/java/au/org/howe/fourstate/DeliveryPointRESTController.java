package au.org.howe.fourstate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

@RestController
@Controller
public class DeliveryPointRESTController {
    @Autowired
    private DeliveryPointDAO deliveryPointDAO;

    @RequestMapping(value = "/rest/deliveryPoint/{dpid}", method = RequestMethod.GET, produces = {"application/json"})
    @ResponseStatus(HttpStatus.OK)
    public DeliveryPoint deliveryPoint(@PathVariable Integer dpid) {
        return deliveryPointDAO.load(dpid);
    }
}
