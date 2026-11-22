import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { map } from 'rxjs';

export function hidePrivateIdentity(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(hidePrivateIdentity);
  if (value && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype) {
    return Object.fromEntries(Object.entries(value).filter(([key]) => key !== 'dni').map(([key, child]) => [key, hidePrivateIdentity(child)]));
  }
  return value;
}

@Injectable()
export class PrivateIdentityInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    // WebSocket events do not expose an HTTP request. The interceptor must
    // leave their payloads untouched instead of throwing while reading a path.
    if (context.getType() !== 'http') return next.handle();
    const request = context.switchToHttp().getRequest<{ originalUrl?: string; url?: string }>();
    const path = (request?.originalUrl ?? request?.url ?? '').split('?')[0];
    const ownIdentity = /^\/api\/v1\/(auth\/(login|register|google\/(login|register))|users\/me|worker-profile\/me(?:\/portfolio)?)$/.test(path);
    return ownIdentity ? next.handle() : next.handle().pipe(map(hidePrivateIdentity));
  }
}
