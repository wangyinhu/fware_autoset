from django.db import models

class IPs(models.Model):
    ip = models.GenericIPAddressField()
