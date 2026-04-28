# Frontend Integration Implementation Guide for Casdoor API

## 1. API Base URL Configuration

### 1.1 Environment-Specific Settings
```javascript
// src/config/api.js
const API_CONFIG = {
  development: {
    API_BASE_URL: 'http://localhost:8000/api',
    OAUTH_BASE_URL: 'http://localhost:8000',
    CLIENT_ID: 'your-dev-client-id',
    REDIRECT_URI: 'http://localhost:3000/callback'
  },
  staging: {
    API_BASE_URL: 'https://staging-api.casdoor.example.com/api',
    OAUTH_BASE_URL: 'https://staging-casdoor.example.com',
    CLIENT_ID: 'your-staging-client-id',
    REDIRECT_URI: 'https://staging-app.example.com/callback'
  },
  production: {
    API_BASE_URL: 'https://api.casdoor.example.com/api',
    OAUTH_BASE_URL: 'https://casdoor.example.com',
    CLIENT_ID: 'your-production-client-id',
    REDIRECT_URI: 'https://app.example.com/callback'
  }
};

const env = process.env.NODE_ENV || 'development';
export const config = API_CONFIG[env];
export const API_BASE_URL = config.API_BASE_URL;
export const OAUTH_BASE_URL = config.OAUTH_BASE_URL;
export const CLIENT_ID = config.CLIENT_ID;
export const REDIRECT_URI = config.REDIRECT_URI;
```

## 2. Authentication Token Management

### 2.1 Token Acquisition

#### 2.1.1 OAuth Authorization Code Flow
```javascript
// src/services/auth.js
import { OAUTH_BASE_URL, CLIENT_ID, REDIRECT_URI } from '../config/api';

export const initiateOAuthLogin = () => {
  const state = generateRandomState();
  const scope = 'openid profile email';
  const nonce = generateRandomNonce();
  
  // Store state and nonce in session storage for verification
  sessionStorage.setItem('oauth_state', state);
  sessionStorage.setItem('oauth_nonce', nonce);
  
  const authUrl = `${OAUTH_BASE_URL}/login/oauth/authorize?` +
    `client_id=${encodeURIComponent(CLIENT_ID)}&` +
    `response_type=code&` +
    `redirect_uri=${encodeURIComponent(REDIRECT_URI)}&` +
    `scope=${encodeURIComponent(scope)}&` +
    `state=${encodeURIComponent(state)}&` +
    `nonce=${encodeURIComponent(nonce)}`;
  
  window.location.href = authUrl;
};

export const handleOAuthCallback = async (code, state) => {
  // Verify state
  const storedState = sessionStorage.getItem('oauth_state');
  if (state !== storedState) {
    throw new Error('Invalid state parameter');
  }
  
  // Exchange code for token
  const response = await fetch(`${API_BASE_URL}/login/oauth/access_token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      grant_type: 'authorization_code',
      client_id: CLIENT_ID,
      code: code
    })
  });
  
  const data = await response.json();
  if (data.status === 'ok') {
    // Store tokens
    localStorage.setItem('access_token', data.data.access_token);
    localStorage.setItem('refresh_token', data.data.refresh_token);
    localStorage.setItem('token_expiry', Date.now() + (data.data.expires_in * 1000));
    return data.data;
  }
  throw new Error(data.msg);
};
```

#### 2.1.2 Password Flow (For trusted applications)
```javascript
export const loginWithPassword = async (username, password) => {
  const response = await fetch(`${API_BASE_URL}/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ username, password })
  });
  
  const data = await response.json();
  if (data.status === 'ok') {
    // Store tokens
    localStorage.setItem('access_token', data.data.access_token);
    localStorage.setItem('refresh_token', data.data.refresh_token);
    localStorage.setItem('token_expiry', Date.now() + (data.data.expires_in * 1000));
    return data.data;
  }
  throw new Error(data.msg);
};
```

### 2.2 Token Renewal
```javascript
export const refreshToken = async () => {
  const refreshToken = localStorage.getItem('refresh_token');
  if (!refreshToken) {
    throw new Error('No refresh token available');
  }
  
  const response = await fetch(`${API_BASE_URL}/login/oauth/refresh_token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      grant_type: 'refresh_token',
      refresh_token: refreshToken
    })
  });
  
  const data = await response.json();
  if (data.status === 'ok') {
    // Update tokens
    localStorage.setItem('access_token', data.data.access_token);
    localStorage.setItem('refresh_token', data.data.refresh_token);
    localStorage.setItem('token_expiry', Date.now() + (data.data.expires_in * 1000));
    return data.data;
  }
  throw new Error('Failed to refresh token');
};
```

### 2.3 Token Invalidation
```javascript
export const logout = async () => {
  try {
    const accessToken = localStorage.getItem('access_token');
    if (accessToken) {
      await fetch(`${API_BASE_URL}/logout`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });
    }
  } catch (error) {
    console.error('Logout error:', error);
  } finally {
    // Clear tokens
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('token_expiry');
    sessionStorage.clear();
  }
};
```

## 3. API Client Implementation

### 3.1 Base API Client
```javascript
// src/services/api.js
import { API_BASE_URL } from '../config/api';
import { refreshToken } from './auth';

class ApiClient {
  constructor() {
    this.baseURL = API_BASE_URL;
    this.tokenRefreshPromise = null;
  }
  
  async getAccessToken() {
    const accessToken = localStorage.getItem('access_token');
    const tokenExpiry = localStorage.getItem('token_expiry');
    
    // Check if token is expired or about to expire (5 minutes before expiry)
    if (!accessToken || !tokenExpiry || Date.now() > parseInt(tokenExpiry) - 300000) {
      if (!this.tokenRefreshPromise) {
        this.tokenRefreshPromise = refreshToken().finally(() => {
          this.tokenRefreshPromise = null;
        });
      }
      await this.tokenRefreshPromise;
      return localStorage.getItem('access_token');
    }
    
    return accessToken;
  }
  
  async request(endpoint, options = {}) {
    const accessToken = await this.getAccessToken();
    
    const config = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': accessToken ? `Bearer ${accessToken}` : '',
        ...options.headers
      }
    };
    
    try {
      const response = await this.fetchWithRetry(`${this.baseURL}${endpoint}`, config);
      
      if (!response.ok) {
        if (response.status === 401) {
          // Token might be invalid, try to refresh
          await refreshToken();
          return this.request(endpoint, options);
        }
        
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.msg || `HTTP error! status: ${response.status}`);
      }
      
      return await response.json();
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }
  
  async fetchWithRetry(url, options, retries = 3, delay = 1000) {
    try {
      return await fetch(url, options);
    } catch (error) {
      if (retries > 0 && this.isNetworkError(error)) {
        await new Promise(resolve => setTimeout(resolve, delay));
        return this.fetchWithRetry(url, options, retries - 1, delay * 2);
      }
      throw error;
    }
  }
  
  isNetworkError(error) {
    return !error.response && (error.message === 'Network error' || 
      error.message.includes('fetch failed') ||
      error.message.includes('network error'));
  }
  
  handleError(error) {
    switch (error.message) {
      case 'invalid_grant':
        // Handle invalid credentials
        console.error('Invalid credentials');
        break;
      case 'invalid_token':
        // Handle token expiration
        console.error('Token expired');
        break;
      case 'rate_limit_exceeded':
        // Handle rate limiting
        console.error('Rate limit exceeded');
        break;
      default:
        // Handle other errors
        console.error('API Error:', error);
    }
  }
  
  // Convenience methods
  get(endpoint, params) {
    const queryString = params ? '?' + new URLSearchParams(params).toString() : '';
    return this.request(`${endpoint}${queryString}`, {
      method: 'GET'
    });
  }
  
  post(endpoint, data) {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data)
    });
  }
  
  put(endpoint, data) {
    return this.request(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data)
    });
  }
  
  delete(endpoint) {
    return this.request(endpoint, {
      method: 'DELETE'
    });
  }
}

export const apiClient = new ApiClient();
export default apiClient;
```

### 3.2 Resource-Specific API Services
```javascript
// src/services/userService.js
import apiClient from './api';

export const userService = {
  getUsers: (params) => apiClient.get('/get-users', params),
  getUser: (id) => apiClient.get(`/get-user?id=${id}`),
  createUser: (userData) => apiClient.post('/add-user', userData),
  updateUser: (userData) => apiClient.post('/update-user', userData),
  deleteUser: (userData) => apiClient.post('/delete-user', userData),
  getUserInfo: () => apiClient.get('/userinfo')
};

// src/services/organizationService.js
import apiClient from './api';

export const organizationService = {
  getOrganizations: (params) => apiClient.get('/get-organizations', params),
  getOrganization: (id) => apiClient.get(`/get-organization?id=${id}`),
  createOrganization: (orgData) => apiClient.post('/add-organization', orgData),
  updateOrganization: (orgData) => apiClient.post('/update-organization', orgData),
  deleteOrganization: (orgData) => apiClient.post('/delete-organization', orgData)
};
```

## 4. Error Handling Strategies

### 4.1 Global Error Handler
```javascript
// src/utils/errorHandler.js
export const handleApiError = (error, options = {}) => {
  const {
    showNotification = true,
    redirectToLogin = true,
    onError = null
  } = options;
  
  let errorMessage = 'An unexpected error occurred';
  let shouldRedirect = false;
  
  if (error.response) {
    // Server returned an error
    switch (error.response.status) {
      case 400:
        errorMessage = 'Bad request. Please check your input.';
        break;
      case 401:
        errorMessage = 'Authentication required.';
        shouldRedirect = redirectToLogin;
        break;
      case 403:
        errorMessage = 'You don\'t have permission to perform this action.';
        break;
      case 404:
        errorMessage = 'Resource not found.';
        break;
      case 429:
        errorMessage = 'Too many requests. Please try again later.';
        break;
      case 500:
        errorMessage = 'Server error. Please try again later.';
        break;
      default:
        errorMessage = `Error ${error.response.status}: ${error.response.statusText}`;
    }
  } else if (error.request) {
    // Request was made but no response
    errorMessage = 'No response from server. Please check your network connection.';
  } else {
    // Error in request setup
    errorMessage = error.message || errorMessage;
  }
  
  if (showNotification) {
    // Show error notification (using your preferred notification library)
    // Example: notification.error(errorMessage);
    console.error(errorMessage);
  }
  
  if (shouldRedirect) {
    // Redirect to login page
    setTimeout(() => {
      window.location.href = '/login';
    }, 1000);
  }
  
  if (onError) {
    onError(error);
  }
  
  return errorMessage;
};
```

### 4.2 Error Boundary Component
```javascript
// src/components/ErrorBoundary.jsx
import React, { Component } from 'react';
import { handleApiError } from '../utils/errorHandler';

class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  
  componentDidCatch(error, errorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    handleApiError(error);
  }
  
  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h2>Something went wrong</h2>
          <p>We're sorry, but something unexpected happened.</p>
          <button onClick={() => window.location.reload()}>
            Try Again
          </button>
        </div>
      );
    }
    
    return this.props.children;
  }
}

export default ErrorBoundary;
```

## 5. State Management Integration

### 5.1 React Context for Auth
```javascript
// src/contexts/AuthContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { loginWithPassword, logout, refreshToken } from '../services/auth';
import { apiClient } from '../services/api';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  
  useEffect(() => {
    checkAuthStatus();
  }, []);
  
  const checkAuthStatus = async () => {
    try {
      const userInfo = await apiClient.get('/userinfo');
      if (userInfo.status === 'ok') {
        setUser(userInfo.data);
        setIsAuthenticated(true);
      }
    } catch (error) {
      console.error('Auth check failed:', error);
    } finally {
      setIsLoading(false);
    }
  };
  
  const login = async (username, password) => {
    const data = await loginWithPassword(username, password);
    await checkAuthStatus();
    return data;
  };
  
  const logoutUser = async () => {
    await logout();
    setUser(null);
    setIsAuthenticated(false);
  };
  
  const value = {
    user,
    isLoading,
    isAuthenticated,
    login,
    logout: logoutUser,
    checkAuthStatus
  };
  
  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
```

### 5.2 Using Auth Context in Components
```javascript
// src/components/ProtectedRoute.jsx
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, isLoading } = useAuth();
  
  if (isLoading) {
    return <div>Loading...</div>;
  }
  
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  
  return children;
};

export default ProtectedRoute;
```

## 6. Performance Optimization

### 6.1 Request Batching
```javascript
// src/utils/batchRequests.js
export const batchRequests = async (requests) => {
  const results = await Promise.allSettled(requests);
  return results.map(result => {
    if (result.status === 'fulfilled') {
      return { success: true, data: result.value };
    } else {
      return { success: false, error: result.reason };
    }
  });
};

// Usage example
const fetchUserData = async () => {
  const requests = [
    apiClient.get('/get-user?id=user1'),
    apiClient.get('/get-user?id=user2'),
    apiClient.get('/get-user?id=user3')
  ];
  
  const results = await batchRequests(requests);
  return results;
};
```

### 6.2 Caching Strategy
```javascript
// src/utils/cache.js
class Cache {
  constructor() {
    this.cache = new Map();
    this.ttl = 5 * 60 * 1000; // 5 minutes
  }
  
  set(key, value) {
    const item = {
      value,
      expiry: Date.now() + this.ttl
    };
    this.cache.set(key, item);
  }
  
  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }
  
  clear() {
    this.cache.clear();
  }
}

export const apiCache = new Cache();

// Usage in API client
async function cachedRequest(key, requestFn) {
  const cachedData = apiCache.get(key);
  if (cachedData) {
    return cachedData;
  }
  
  const data = await requestFn();
  apiCache.set(key, data);
  return data;
}
```

## 7. Testing Strategies

### 7.1 Unit Tests for API Client
```javascript
// src/services/__tests__/api.test.js
import apiClient from '../api';

jest.mock('../auth', () => ({
  refreshToken: jest.fn(() => Promise.resolve({ access_token: 'new-token' }))
}));

describe('ApiClient', () => {
  beforeEach(() => {
    localStorage.setItem('access_token', 'test-token');
    localStorage.setItem('token_expiry', (Date.now() + 3600000).toString());
  });
  
  afterEach(() => {
    localStorage.clear();
    jest.clearAllMocks();
  });
  
  test('should make a GET request with authorization header', async () => {
    global.fetch = jest.fn(() => Promise.resolve({
      ok: true,
      json: () => Promise.resolve({ status: 'ok', data: { test: 'data' } })
    }));
    
    const result = await apiClient.get('/test');
    expect(global.fetch).toHaveBeenCalledWith(
      'http://localhost:8000/api/test',
      expect.objectContaining({
        headers: expect.objectContaining({
          'Authorization': 'Bearer test-token'
        })
      })
    );
    expect(result).toEqual({ status: 'ok', data: { test: 'data' } });
  });
  
  test('should handle 401 error and refresh token', async () => {
    const refreshToken = require('../auth').refreshToken;
    
    global.fetch = jest.fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: () => Promise.resolve({ msg: 'Unauthorized' })
      })
      .mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve({ status: 'ok', data: { test: 'data' } })
      });
    
    const result = await apiClient.get('/test');
    expect(refreshToken).toHaveBeenCalled();
    expect(global.fetch).toHaveBeenCalledTimes(2);
    expect(result).toEqual({ status: 'ok', data: { test: 'data' } });
  });
});
```

### 7.2 Integration Tests
```javascript
// src/services/__tests__/auth.test.js
import { loginWithPassword, logout } from '../auth';

describe('Auth Service', () => {
  beforeEach(() => {
    global.fetch = jest.fn();
    localStorage.clear();
  });
  
  test('should login successfully', async () => {
    global.fetch.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({
        status: 'ok',
        data: {
          access_token: 'test-access-token',
          refresh_token: 'test-refresh-token',
          expires_in: 3600
        }
      })
    });
    
    const result = await loginWithPassword('testuser', 'password123');
    expect(global.fetch).toHaveBeenCalledWith(
      'http://localhost:8000/api/login',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ username: 'testuser', password: 'password123' })
      })
    );
    expect(localStorage.getItem('access_token')).toBe('test-access-token');
    expect(localStorage.getItem('refresh_token')).toBe('test-refresh-token');
    expect(result).toEqual({
      access_token: 'test-access-token',
      refresh_token: 'test-refresh-token',
      expires_in: 3600
    });
  });
  
  test('should logout successfully', async () => {
    localStorage.setItem('access_token', 'test-token');
    
    global.fetch.mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ status: 'ok' })
    });
    
    await logout();
    expect(global.fetch).toHaveBeenCalledWith(
      'http://localhost:8000/api/logout',
      expect.objectContaining({
        method: 'POST',
        headers: {
          'Authorization': 'Bearer test-token'
        }
      })
    );
    expect(localStorage.getItem('access_token')).toBe(null);
    expect(localStorage.getItem('refresh_token')).toBe(null);
  });
});
```

## 8. Best Practices

### 8.1 Security Best Practices
- **Never store sensitive data** in localStorage (use sessionStorage for temporary data)
- **Always use HTTPS** for API communications
- **Implement CSRF protection** for stateful operations
- **Validate all user input** before sending to API
- **Use parameterized queries** to prevent injection attacks

### 8.2 Performance Best Practices
- **Implement request batching** for multiple similar requests
- **Use caching** for frequently accessed data
- **Implement exponential backoff** for retries
- **Optimize payload size** by only sending necessary data
- **Use HTTP/2 or HTTP/3** for better performance

### 8.3 Reliability Best Practices
- **Implement circuit breakers** to prevent cascading failures
- **Use retry logic** for transient failures
- **Implement graceful degradation** for non-critical features
- **Monitor API usage** and performance
- **Implement proper error handling** at all levels

## 9. Conclusion

This frontend integration guide provides a comprehensive framework for integrating Casdoor API into frontend applications. By following these guidelines, developers can create secure, efficient, and reliable applications that leverage Casdoor's identity management capabilities.

The implementation includes:
- Environment-specific configuration
- Secure token management
- Robust error handling
- Performance optimization
- Comprehensive testing

By combining these elements, developers can build applications that provide a seamless user experience while maintaining the highest security standards.