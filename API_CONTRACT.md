# API Contract Notes

This is an integration proposal only. Verify all route names and payloads with the current housing backend before connecting the mobile app.

## Example response: `GET /housing/residents`

```json
{
  "data": [
    {
      "id": "res_001",
      "employee_code": "EMP-1001",
      "name": "Employee Name",
      "job_title": "Operator",
      "company": "Company",
      "department": "Operations",
      "shift": "day",
      "rotation": "14/7",
      "attendance_status": "present",
      "building_id": "building_01",
      "room_id": "room_101",
      "bed_id": "bed_01",
      "check_in_date": "2026-10-01",
      "leave_until": null
    }
  ]
}
```

## Suggested safeguards

- Authenticate users and check permissions on the server for every request.
- Make bed assignment and transfer operations transactional to prevent two employees receiving one bed.
- Retain historical assignment/attendance events rather than silently overwriting history.
- Require an approval record for destructive or financially significant actions.
- Return clear conflict responses (for example HTTP 409) when a bed has been assigned by another user.
- Use HTTPS, short-lived access tokens, and controlled refresh tokens.
- Keep database credentials on the server, not in the Android application.
