import type { AxiosInstance, AxiosError, InternalAxiosRequestConfig, AxiosResponse } from 'axios';
import { logger } from './logger';

/**
 * Setup axios interceptors for request/response logging
 */
export function setupApiLogging(axiosInstance: AxiosInstance): void {
  // Request interceptor - log outgoing requests
  axiosInstance.interceptors.request.use(
    (config: InternalAxiosRequestConfig) => {
      const { method, url, baseURL, params, data } = config;
      const fullUrl = `${baseURL || ''}${url || ''}`;
      
      logger.debug(
        `API Request: ${method?.toUpperCase()} ${fullUrl}`,
        'API',
        {
          method: method?.toUpperCase(),
          url: fullUrl,
          params,
          data,
          headers: config.headers,
        }
      );
      
      return config;
    },
    (error: AxiosError) => {
      logger.error('API Request Error', 'API', error);
      return Promise.reject(error);
    }
  );

  // Response interceptor - log responses and errors
  axiosInstance.interceptors.response.use(
    (response: AxiosResponse) => {
      const { config, status, statusText, data } = response;
      const fullUrl = `${config.baseURL || ''}${config.url || ''}`;
      
      logger.debug(
        `API Response: ${config.method?.toUpperCase()} ${fullUrl} - ${status} ${statusText}`,
        'API',
        {
          method: config.method?.toUpperCase(),
          url: fullUrl,
          status,
          statusText,
          data,
        }
      );
      
      return response;
    },
    (error: AxiosError) => {
      if (error.response) {
        // Server responded with error status
        const { config, response } = error;
        const fullUrl = `${config?.baseURL || ''}${config?.url || ''}`;
        
        logger.error(
          `API Error: ${config?.method?.toUpperCase()} ${fullUrl} - ${response.status} ${response.statusText}`,
          'API',
          {
            method: config?.method?.toUpperCase(),
            url: fullUrl,
            status: response.status,
            statusText: response.statusText,
            data: response.data,
            error: error.message,
          }
        );
      } else if (error.request) {
        // Request made but no response received
        logger.error(
          'API Error: No response received',
          'API',
          {
            message: error.message,
            request: error.request,
          }
        );
      } else {
        // Error setting up request
        logger.error(
          'API Error: Request setup failed',
          'API',
          {
            message: error.message,
          }
        );
      }
      
      return Promise.reject(error);
    }
  );
}
