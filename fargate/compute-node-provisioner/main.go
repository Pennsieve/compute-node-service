package main

import (
	"context"
	"log"
	"os"
)

func main() {
	log.Println("Running compute node provisioner")
	_ = context.Background()

	// TODO: remove
	log.Println("ENV", os.Getenv("ENV"))

	log.Println("provisioning complete")
}
