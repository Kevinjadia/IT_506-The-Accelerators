﻿#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <iostream>
#include <stdlib.h>
#include <stdio.h>
#include<conio.h>
#include <cuda.h>
#define BLOCK_SIZE 32
using namespace std;

__global__ void split(double* C11, double* C12, double* C21, double* C22, double* C, int n) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C11[i * n + j] = C[i * 2 * n + j];
		C12[i * n + j] = C[i * 2 * n + j + n];
		C21[i * n + j] = C[(i + n) * 2 * n + j];
		C22[i * n + j] = C[(i + n) * 2 * n + j + n];
	}
}

__global__ void merge(double* C11, double* C12, double* C21, double* C22, double* C, int n) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * 2 * n + j] = C11[i * n + j];
		C[i * 2 * n + j + n] = C12[i * n + j];
		C[(i + n) * 2 * n + j] = C21[i * n + j];
		C[(i + n) * 2 * n + j + n] = C22[i * n + j];
	}
}
__global__ void transpose(double* M, double* R, int n) {

	int column = blockDim.x * blockIdx.x + threadIdx.x;
	int row = blockDim.x * blockIdx.y + threadIdx.y;

	if (column < n && row < n) {
		R[column * n + row] = M[column + row * n];
	}
}
__global__ void add(double* A, double* B, double* C, int n) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * n + j] = A[i * n + j] + B[i * n + j];
	}
}


__global__ void sub(double* A, double* B, double* C, int n) {
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	int j = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * n + j] = A[i * n + j] - B[i * n + j];
	}
}


__global__ void mul(double* A, double* B, double* C, int n) {
	int j = blockIdx.x * blockDim.x + threadIdx.x;
	int i = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * n + j] = 0;
		for (int k = 0; k < n; k++) {
			C[i * n + j] += A[i * n + k] * B[i * n + k];
		}
	}
}


__global__ void mul_add(double* A, double* B, double* T, double* C, int n) {
	int j = blockIdx.x * blockDim.x + threadIdx.x;
	int i = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * n + j] = T[i * n + j];
		for (int k = 0; k < n; k++) {
			C[i * n + j] += A[i * n + k] * B[k * n + j];
		}
	}
}

__global__ void mul_sub_inc(double* A, double* B, double* T, double* C1, double* C2, int n) {
	int j = blockIdx.x * blockDim.x + threadIdx.x;
	int i = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C1[i * n + j] = 0;
		for (int k = 0; k < n; k++) {
			C1[i * n + j] += A[i * n + k] * B[k * n + j];
		}
		C1[i * n + j] = T[i * n + j] - C1[i * n + j];
		C2[i * n + j] += T[i * n + j];
	}
}

__global__ void mul_inc_inc_inc(double* A, double* B, double* C, double* T, double* C1, double* C2, int n) {
	int j = blockIdx.x * blockDim.x + threadIdx.x;
	int i = blockIdx.y * blockDim.y + threadIdx.y;
	if (i < n && j < n) {
		C[i * n + j] = 0;
		for (int k = 0; k < n; k++) {
			C[i * n + j] += A[i * n + k] * B[k * n + j];
		}
		C1[i * n + j] += C[i * n + j];
		C2[i * n + j] += C1[i * n + j];
		C1[i * n + j] += T[i * n + j];
	}
}
void compare(double* res1, double* res2, int n) {
	int fail = 0;
	for (int i = 0; i < n; i++) {
		double a, b;
		a = res1[i] < 0 ? -res1[i] : res1[i];
		b = res2[i] < 0 ? -res2[i] : res2[i];
		if (a < 0.01 && b < 0.01) {
			continue;
		}
		if (i < 5) {
			printf("i = %d\t%lf\t%lf\n", i, a, b);
		}
		double diff = (a - b) / (a + 0.000001);
		if (diff < 0) {
			diff = -diff;
		}
		if (diff > 0.0005) {
			fail++;
		}
	}
	printf("Number of errors: %d\n", fail);
}
void strassen(double* A, double* B, double* C, int n) {


	double* A_gpu, * B_gpu, * C_gpu;
	dim3 block(BLOCK_SIZE, BLOCK_SIZE);

	//Allocating memories to gpu variables
	cudaMalloc((void**)&A_gpu, sizeof(double) * n * n);
	cudaMalloc((void**)&B_gpu, sizeof(double) * n * n);
	cudaMalloc((void**)&C_gpu, sizeof(double) * n * n);

	//copying data from host to device
	cudaMemcpy(A_gpu, A, sizeof(double) * n * n, cudaMemcpyHostToDevice);
	cudaMemcpy(B_gpu, B, sizeof(double) * n * n, cudaMemcpyHostToDevice);




	int m = n >> 1;
	dim3 grid((size_t)ceil((double)m / (double)block.x), (size_t)ceil((double)m / (double)block.y));
	double* A11, * A12, * A21, * A22, * B11, * B12, * B21, * B22, * C11, * C12, * C21, * C22, * T1, * T2, *TT2;
	cudaMalloc((void**)&A11, sizeof(double) * m * m);
	cudaMalloc((void**)&A12, sizeof(double) * m * m);
	cudaMalloc((void**)&A21, sizeof(double) * m * m);
	cudaMalloc((void**)&A22, sizeof(double) * m * m);
	cudaMalloc((void**)&B11, sizeof(double) * m * m);
	cudaMalloc((void**)&B12, sizeof(double) * m * m);
	cudaMalloc((void**)&B21, sizeof(double) * m * m);
	cudaMalloc((void**)&B22, sizeof(double) * m * m);
	cudaMalloc((void**)&C11, sizeof(double) * m * m);
	cudaMalloc((void**)&C12, sizeof(double) * m * m);
	cudaMalloc((void**)&C21, sizeof(double) * m * m);
	cudaMalloc((void**)&C22, sizeof(double) * m * m);
	cudaMalloc((void**)&T1, sizeof(double) * m * m);
	cudaMalloc((void**)&T2, sizeof(double) * m * m);
	cudaMalloc((void**)&TT2, sizeof(double) * m * m);


	split << <grid, block >> > (A11, A12, A21, A22, A_gpu, m);
	cudaDeviceSynchronize();
	split << <grid, block >> > (B11, B12, B21, B22, B_gpu, m);
	cudaDeviceSynchronize();

	sub << <grid, block >> > (A11, A21, T1, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (B22, B12, T2, m);
	cudaDeviceSynchronize();
	transpose << <grid, block >> > (T2, TT2, m);
	cudaDeviceSynchronize();
	mul << <grid, block >> > (T1, TT2, C21, m);
	cudaDeviceSynchronize();
	add << <grid, block >> > (A21, A22, T1, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (B12, B11, T2, m);
	cudaDeviceSynchronize();
	transpose << <grid, block >> > (T2, TT2, m);
	cudaDeviceSynchronize();
	mul << <grid, block >> > (T1, TT2, C22, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (T1, A11, T1, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (B22, T2, T2, m);
	cudaDeviceSynchronize();
	transpose << <grid, block >> > (T2, TT2, m);
	cudaDeviceSynchronize();
	mul << <grid, block >> > (T1, TT2, C11, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (A12, T1, T1, m);
	cudaDeviceSynchronize();
	mul_add << <grid, block >> > (T1, B22, C22, C12, m);
	cudaDeviceSynchronize();
	mul_inc_inc_inc << <grid, block >> > (A11, B11, T1, C21, C11, C12, m);
	cudaDeviceSynchronize();
	sub << <grid, block >> > (T2, B21, T2, m);
	cudaDeviceSynchronize();
	mul_sub_inc << <grid, block >> > (A22, T2, C11, C21, C22, m);
	cudaDeviceSynchronize();
	mul_add << <grid, block >> > (A12, B21, T1, C11, m);
	cudaDeviceSynchronize();

	merge << <grid, block >> > (C11, C12, C21, C22, C_gpu, m);
	cudaDeviceSynchronize();


	cudaFree(A11);
	cudaFree(A12);
	cudaFree(A21);
	cudaFree(A22);
	cudaFree(B11);
	cudaFree(B12);
	cudaFree(B21);
	cudaFree(B22);
	cudaFree(T1);
	cudaFree(T2);

	cudaMemcpy(C, C_gpu, sizeof(double) * n * n, cudaMemcpyDeviceToHost);

	cudaFree(A_gpu);
	cudaFree(B_gpu);
	cudaFree(C_gpu);


}
void serial_mm(double* hostA, double* hostB, double* C_cmp, int n) {
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < n; j++) {
			C_cmp[i * n + j] = 0;

			for (int k = 0; k < n; k++) {
				C_cmp[i * n + j] += hostA[i * n + k] * hostB[k * n + j];
			}
		}
	}
}

int main()
{

	double* hostA, * hostB, * hostC, * C_cmp;
	int minSize = pow(2, 1);
	int maxSize = pow(2, 13);
	int size, k = 1;

	cudaEvent_t start, stop;
	float milliseconds = 0;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);



	for (size = minSize; size <= maxSize; size *= 2, k++) {

		int tot_allocation_size = size * size * sizeof(double);
		//Dynamically Allocating Memory

		hostA = (double*)malloc(tot_allocation_size);
		hostB = (double*)malloc(tot_allocation_size);
		hostC = (double*)malloc(tot_allocation_size);
		C_cmp = (double*)malloc(tot_allocation_size);


		// initialization of A B by some random variables
		for (int i = 0; i < size; i++) {
			for (int j = 0; j < size; j++) {
				hostA[i * size + j] = 2.00;
				hostB[i * size + j] = 2.00;
				hostC[i * size + j] = 0;
				C_cmp[i * size + j] = 0;
			}
		}

		//runs=maxSize/size;
		cudaEventRecord(start);
		strassen(hostA, hostB, hostC, size);
		cudaEventRecord(stop);

		cudaEventSynchronize(stop);

		cudaEventElapsedTime(&milliseconds, start, stop);

		printf("\n -------------------------------------\n");
		printf("\n input size:%d x %d(%d) \t time:%lf\n", size, size, k, milliseconds / 1000);
	//	s1 = clock();
		serial_mm(hostA, hostB, C_cmp, size);
	//	e1 = clock();
	//	walltime = (e1 - s1) / (double)CLOCKS_PER_SEC;
		printf("\n -------------------------------------\n");
		compare(hostC, C_cmp,size * size);
		//for (int i = 0; i < size; i++) {
		//	for (int j = 0; j < size; j++) {
		//		printf("%lf\t", hostC[i * size + j]);
		//	}
		//	printf("\n");
		//}

	}

	return 0;
}