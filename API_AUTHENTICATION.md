# API Authentication

This document describes how to configure and use basic authentication for the Family Tree API.

## Overview

The Family Tree API uses HTTP Basic Authentication to protect sensitive endpoints. The health endpoint (`/api/health`) remains public for monitoring purposes.

## Protected Endpoints

- `POST /api/family_members/answer` - AI-powered family tree queries
- `GET /api/family_members` - Family tree data retrieval
- `OPTIONS /api/family_members/*` - CORS preflight requests

## Public Endpoints

- `GET /api/health` - System health check

## Configuration

### Environment Variables

Set these environment variables to enable authentication:

```bash
export FAMILY_TREE_API_USERNAME="your_username"
export FAMILY_TREE_API_PASSWORD="your_secure_password"
```

### Development Mode

If no credentials are configured, authentication is **disabled** for development convenience.

### Production Deployment

For production deployment on Fly.io, set the environment variables:

```bash
# Set secrets in Fly.io
fly secrets set FAMILY_TREE_API_USERNAME="your_username"
fly secrets set FAMILY_TREE_API_PASSWORD="your_secure_password"
```

## Usage Examples

### Without Authentication (Development)

```bash
curl -X POST http://localhost:4000/api/family_members/answer \
  -H "Content-Type: application/json" \
  -d '{"question": "Who is Juan Pablo?"}'
```

### With Basic Authentication

```bash
# Using curl with username:password
curl -X POST http://localhost:4000/api/family_members/answer \
  -H "Content-Type: application/json" \
  -u "admin:secret123" \
  -d '{"question": "Who is Juan Pablo?"}'

# Using curl with Authorization header
curl -X POST http://localhost:4000/api/family_members/answer \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $(echo -n 'admin:secret123' | base64)" \
  -d '{"question": "Who is Juan Pablo?"}'
```

### JavaScript/Fetch Example

```javascript
const username = 'admin';
const password = 'secret123';
const credentials = btoa(`${username}:${password}`);

fetch('https://your-app.fly.dev/api/family_members/answer', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Basic ${credentials}`
  },
  body: JSON.stringify({
    question: 'Who is Juan Pablo?'
  })
})
.then(response => response.json())
.then(data => console.log(data));
```

## Error Responses

### 401 Unauthorized (Missing Authentication)

```json
{
  "error": "Authentication required",
  "message": "Please provide valid credentials to access this endpoint"
}
```

The response includes a `WWW-Authenticate` header:
```
WWW-Authenticate: Basic realm="Family Tree API"
```

### 401 Unauthorized (Invalid Credentials)

Same response as missing authentication, but logged differently on the server.

## Security Considerations

1. **HTTPS Only**: Always use HTTPS in production to protect credentials in transit
2. **Strong Passwords**: Use strong, unique passwords for API access
3. **Credential Rotation**: Regularly rotate API credentials
4. **Environment Variables**: Never hardcode credentials in your application code
5. **Logging**: Authentication failures are logged for security monitoring

## Testing Authentication

You can test the authentication setup using the provided examples above. The system will:

- Allow access without credentials in development (when no env vars are set)
- Require valid credentials when authentication is configured
- Return appropriate error messages for invalid or missing credentials
- Keep the health endpoint public for monitoring

## Troubleshooting

### Authentication Not Working

1. Ensure environment variables are set correctly
2. Restart the server after setting environment variables
3. Check that credentials are base64 encoded properly
4. Verify the Authorization header format: `Basic <base64-encoded-credentials>`

### Development Mode Issues

If you want to disable authentication in development, simply don't set the environment variables or unset them:

```bash
unset FAMILY_TREE_API_USERNAME
unset FAMILY_TREE_API_PASSWORD
```

Then restart the server.
