package main

import "context"

type Provisioner interface {
	Run(context.Context)
}
