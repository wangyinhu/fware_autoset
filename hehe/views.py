from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django import forms
from hehe.models import IPs
import os, shutil


def clear_folder(folder):
    for filename in os.listdir(folder):
        file_path = os.path.join(folder, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print('Failed to delete %s. Reason: %s' % (file_path, e))


def get_available_disk():
    path = '/'
    st = os.statvfs(path)
    # free blocks available * fragment size
    bytes_avail = (st.f_bavail * st.f_frsize)
    gigabytes = bytes_avail / 1024 / 1024 / 1024
    return gigabytes


def clear_download():
    print('clear_download')
    download_dir = '../Downloads'
    clear_folder(download_dir)


def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0]
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def index(request):
    return render(request, 'hehe/index.html')


@login_required
def home(request):
    ip = get_client_ip(request)
    print(ip)
    if IPs.objects.filter(ip=ip).count():
        return render(request, 'hehe/ok.html', {'status': 'old', 'ip': ip})
    else:
        IPs.objects.create(ip=ip)
        os.system('echo "' + ip + '" > $HOME/pass_ip.txt')
        return render(request, 'hehe/ok.html', {'status': 'new', 'ip': ip})


@login_required
def man(request):
    ip = get_client_ip(request)
    avail = get_available_disk()
    print(request.method)
    if request.method == 'POST':
        print('POSTPOSTPOST')
        clear_download()
        return render(request, 'hehe/ok.html', {'status': '已清空', 'ip': f'{round(float(avail), 2)}GB'})
    else:
        return render(request, 'hehe/man.html', {'avail':  round(float(avail), 2), 'ip': ip})


@login_required
def flush(request):
    home_dir = os.environ['HOME']
    with open(home_dir + "/flush_ip.txt", 'a+') as ff:
        for i in IPs.objects.all():
            ff.write(i.ip + '\n')
    IPs.objects.all().delete()
    return render(request, 'hehe/ok.html', {'status': 'new', 'ip': 'flush'})


class NameForm(forms.Form):
    ipaddress = forms.GenericIPAddressField(label='IP addres')


# Create your views here.
@login_required
def form(request):
    # if this is a POST request we need to process the form data
    if request.method == 'POST':
        # create a form instance and populate it with data from the request:
        form = NameForm(request.POST)
        # check whether it's valid:
        if form.is_valid():
            # process the data in form.cleaned_data as required
            ipaddress = form.cleaned_data['ipaddress']
            print(ipaddress)
            # redirect to a new URL:
            return render(request, 'hehe/ok.html')

    # if a GET (or any other method) we'll create a blank form
    else:
        form = NameForm()
    return render(request, 'hehe/index.html', {'form': form})
