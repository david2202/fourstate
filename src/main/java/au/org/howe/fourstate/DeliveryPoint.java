package au.org.howe.fourstate;

public class DeliveryPoint {
    private Integer dpid;
    private String addressLine1;
    private String addressLine2;

    public DeliveryPoint(Integer dpid, String addressLine1, String addressLine2) {
        this.dpid = dpid;
        this.addressLine1 = addressLine1;
        this.addressLine2 = addressLine2;
    }

    public Integer getDpid() {
        return dpid;
    }

    public String getAddressLine1() {
        return addressLine1;
    }

    public String getAddressLine2() {
        return addressLine2;
    }
}
