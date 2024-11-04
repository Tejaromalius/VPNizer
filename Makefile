# Define variables
SOURCE := src/vpnizer.sh
DEST := ~/.local/bin/vpnizer

# Targets
.PHONY: install clean

install:
	mkdir -p ~/.local/bin
	cp $(SOURCE) $(DEST)
	chmod +x $(DEST)

clean:
	rm -f $(DEST)
