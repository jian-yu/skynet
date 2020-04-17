include platform.mk

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
LUA_LIB_PATH ?= lualib

SKYNET_BUILD_PATH ?= .

CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
# CFLAGS += -DUSE_PTHREAD_LOCK

# lua

LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua

$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC='$(CC) -std=gnu99' $(PLAT)

# https : turn on TLS_MODULE to add https support

#TLS_MODULE=ltls
TLS_LIB=
TLS_INC=

# jemalloc

# JEMALLOC_STATICLIB := 3rd/jemalloc/lib/libjemalloc_pic.a
# JEMALLOC_INC := 3rd/jemalloc/include/jemalloc

all : 
	
.PHONY : #jemalloc update3rd

# MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)

# $(JEMALLOC_STATICLIB) : 3rd/jemalloc/Makefile
# 	cd 3rd/jemalloc && $(MAKE) CC=$(CC) 

# 3rd/jemalloc/autogen.sh :
# 	git submodule update --init

# 3rd/jemalloc/Makefile : | 3rd/jemalloc/autogen.sh
# 	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-prof

# jemalloc : $(MALLOC_STATICLIB)

# update3rd :
# 	rm -rf 3rd/jemalloc && git submodule update --init
updateluasocket :
	git submodule update --init
# skynet	

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet \
  client \
  bson md5 sproto lpeg $(TLS_MODULE) cjson socket

LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-profile.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-debugchannel.c \
  lua-datasheet.c \
  lua-sharetable.c \
  \

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

all : cleansocket updateluasocket \
  $(SKYNET_BUILD_PATH)/skynet \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/skynet : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) $(LUA_LIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ -Iskynet-src

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/client.so : lualib-src/lua-clientsocket.c lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilualib-src/sproto $^ -o $@ 

$(LUA_CLIB_PATH)/ltls.so : lualib-src/ltls.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src -L$(TLS_LIB) -I$(TLS_INC) $^ -o $@ -lssl

$(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg $^ -o $@ 

$(LUA_CLIB_PATH)/cjson.so : | $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE) LUA_INCLUDE_DIR=../../$(LUA_INC) CC=$(CC) CJSON_LDFLAGS="$(SHARED)" && cd ../.. && cp 3rd/lua-cjson/cjson.so $@ && cp -r 3rd/lua-cjson/lua/* $(LUA_LIB_PATH)

$(LUA_CLIB_PATH)/socket.so : | $(LUA_CLIB_PATH)
	cd 3rd/luasocket && $(MAKE) LUAINC=../../$(LUA_INC) LD="$(TARGET_CROSS)ld -shared" \
	&& cd ../.. && mkdir $(LUA_CLIB_PATH)/socket && cp 3rd/luasocket/src/socket-3.0-rc1.so $(LUA_CLIB_PATH) && ln -sf $(LUA_CLIB_PATH)/socket.so.3.0-rc1 $(LUA_CLIB_PATH)/socket/core.so \
  && mkdir $(LUA_CLIB_PATH)/mime && cp 3rd/luasocket/src/mime-1.0.3.so $(LUA_CLIB_PATH) && ln -sf $(LUA_CLIB_PATH)/mime.so.1.0.3 $(LUA_CLIB_PATH)/mime/core.so \
	&& mkdir $(LUA_LIB_PATH)/socket && cp 3rd/luasocket/src/ftp.lua 3rd/luasocket/src/headers.lua 3rd/luasocket/src/http.lua 3rd/luasocket/src/smtp.lua 3rd/luasocket/src/tp.lua 3rd/luasocket/src/url.lua $(LUA_LIB_PATH)/socket \
	&& cp 3rd/luasocket/src/socket.lua 3rd/luasocket/src/mime.lua 3rd/luasocket/src/ltn12.lua $(LUA_LIB_PATH)

clean :
	rm -f $(SKYNET_BUILD_PATH)/skynet $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so

cleanall: clean
ifneq (,$(wildcard 3rd/jemalloc/Makefile))
	cd 3rd/jemalloc && $(MAKE) clean && rm Makefile
endif
ifneq (,$(wildcard 3rd/luasocket/makefile))
	cd 3rd/luasocket && $(MAKE) clean
endif
	cd 3rd/lua && $(MAKE) clean
	cd 3rd/lua-cjson && $(MAKE) clean
	rm -rf $(LUA_LIB_PATH)/socket
	rm -rf $(LUA_CLIB_PATH)/socket
	rm -rf $(LUA_CLIB_PATH)/mime
	rm -rf $(LUA_LIB_PATH)/cjson $(LUA_LIB_PATH)/json2lua.lua $(LUA_LIB_PATH)/lua2json.lua 
	rm -rf $(LUA_LIB_PATH)/mime.lua $(LUA_LIB_PATH)/ltn12.lua $(LUA_LIB_PATH)/socket.lua
	rm -f $(LUA_STATICLIB)

cleansocket:
	rm -rf $(LUA_LIB_PATH)/socket
	rm -rf $(LUA_CLIB_PATH)/socket
	rm -rf $(LUA_CLIB_PATH)/mime
