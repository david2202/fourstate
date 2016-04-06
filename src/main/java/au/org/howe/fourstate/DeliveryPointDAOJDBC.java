package au.org.howe.fourstate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcDaoSupport;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

@Component
public class DeliveryPointDAOJDBC implements DeliveryPointDAO {
    private static final String loadSQL = "SELECT dpid,address_line_1,address_line_2 FROM DELIVERY_POINT WHERE dpid=:dpid";

    @Autowired
    private NamedParameterJdbcTemplate namedParameterJdbcTemplate;

    @Override
    public DeliveryPoint load(Integer dpid) {
        SqlParameterSource sqlParameterSource = new MapSqlParameterSource("dpid", dpid);
        return namedParameterJdbcTemplate.queryForObject(loadSQL,sqlParameterSource, (resultSet, i) -> {
            return new DeliveryPoint(resultSet.getInt("dpid"), resultSet.getString("address_line_1"), resultSet.getString("address_line_2"));
        });
    }
}
