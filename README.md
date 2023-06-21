### QuPath and ImageJ in a ubuntu-based vnc desktop

Taken from https://git.embl.de/heriche/docker-vnc-qupath/-/tree/master/

Desktop from https://www.github.com/fcwu/dockelr-ubuntu-vnc-desktop

QuPath available at: https://github.com/qupath/qupath

Build with: `docker build --rm -t <your_image_name> .`

Run with: `docker run -p <exposed port>:80 <your_image_name>`

Access it: `http://127.0.0.1:<exposed port>`, or from `localhost:<exposed port>`

### Hosted image

Currently hosted on public dockerhub at `mitpenguin/qupath_vnc`. To use the image without local build, run 
`docker pull mitpenguin/qupath_vnc:<tag>` to get the image down, then run using 
`docker run -p <exposed port>:80 mitpenguin/qupath_vnc:<tag>`. Can use `latest` for tag, or any previous versions.

Resolution can be changed by adding `-e RESOLUTION=<pixel width>x<pixel height>`. default is `2560x1440`.

### Mount volumes

To pass a volume into the docker file, add the option `-v /home/usr/path/to/data:/root/Desktop/folder_name` to have a folder on 
the desktop with `folder_name`. This volume is active, meaning you can pass in files directly to the mounted volume while
the the container is running.

for example:
```bash
docker run -d -p 6080:80 -v /home/andy_tu/data/Phenocycler:/root/Desktop/Phenocycler \
-v /home/andy_tu/immunai-product/research:/root/Desktop/research/ mitpenguin/qupath_vnc:v0.3.2_fiji
```

### To Stop container

Assuming the container was started in detached mode (`-d` flag in `run` command), run `docker stop <unique container id>` 
in the terminal to pause the container. Once paused, the container can be restarted with `docker start <unique container id>`.

If you don't think you'd need to re-use the container, you can also add `-rm` to the run command, which will automatically
remove the container after it's stopped.

### Content of the container

The container contains a Ubuntu desktop, connected via vnc. This container also added QuPath and FIJI, as well as some
other useful tools such as Firefox and Sublime. 

The StarDist extension for qupath is stored in `/root/QuPath/v0.4/extensions`. To use, open qupath, then go to 'Edit' -> 
'Preferences', and under 'Extension' set directory to `/root/QuPath/v0.4`. Then go to 'Extensions' -> 'Installed extensions'
click open extensions directory to load. It won't show up in the menu until Qupath is restared. 

### TODO:

QOL improvements: user preference file can be saved and exported. That way they can be used to set up new container with
preset QuPath preferences.

The user previlege of the docker image is just the root user of the docker container, not the user of the VM/terminal.
The vnc DeskTop Q&A does give you the `--USER` and `--PASSWORD` tag to put in custom user and password, but i'm not
sure that's necessarily going to work, given that according to [this]
(https://stackoverflow.com/questions/64857370/using-current-user-when-running-container-in-docker-compose) user and 
password that are created within the container is not going to work outside of it. 

This means the files written via the container might not always have the correct permissions outside of it. It's solvable
for now using a `chmod` command, but should look into a more permenant solution. 

To be safe, try not to mount `git` root directory to the container. `git lfs` sometimes run into troubles afterwards.

There have also been cases where the mounted volumes had permission chanaged from `$USER` to `root`. chown command can solve it.


