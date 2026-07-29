from django.contrib import admin
from django.urls import include, path, re_path
from django.conf import settings
from django.views.static import serve
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path('admin/', admin.site.urls),

    # Authentification JWT
    path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Apps métier
    path('api/comptes/', include('accounts.urls')),
    path('api/menu/', include('menu.urls')),
    path('api/', include('orders.urls')),
]

# Sert les photos de plats uploadées, en dev comme en prod.
urlpatterns += [
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
]
