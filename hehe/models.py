from django.db import models

class IPs(models.Model):
    ip = models.GenericIPAddressField()

    def __str__(self):
        return str(self.ip)
