from django.contrib import admin
from hehe.models import IPs
from django.contrib.auth.models import Group


admin.site.register(IPs)
admin.site.unregister(Group)


admin.site.site_header = '课程设计'


