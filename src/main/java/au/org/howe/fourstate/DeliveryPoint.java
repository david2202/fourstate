package au.org.howe.fourstate;

public class DeliveryPoint {
    private Integer dpid;
    private String address;

    public DeliveryPoint(Integer dpid, String address) {
        this.dpid = dpid;
        this.address = address;
    }

    public Integer getDpid() {
        return dpid;
    }

    public String getAddress() {
        return address;
    }
}
